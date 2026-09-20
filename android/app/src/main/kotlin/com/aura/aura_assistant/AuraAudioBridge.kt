package com.aura.aura_assistant

import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.NoiseSuppressor
import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.vosk.LibVosk
import org.vosk.LogLevel
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File
import kotlin.math.sqrt

/**
 * AuraAudioBridge — REAL native audio pipeline for the AURA voice phase.
 *
 * Registers three MethodChannel + EventChannel pairs on ONE shared microphone
 * capture (no duplicate mic pipelines):
 *
 *  1) output_level  — REAL AURA output amplitude via android.media.audiofx.Visualizer
 *                     attached to the OUTPUT MIX (session 0). Computes RMS from
 *                     the Visualizer waveform -> normalised 0..1. This is the
 *                     device's own audio output (what AURA is playing); it does
 *                     NOT capture other apps' private audio.
 *
 *  2) mic_vad       — Post-processing RMS + zero-crossing rate for the Dart VAD
 *                     (barge-in), computed from the SHARED AudioRecord.
 *
 *  3) wake          — REAL acoustic keyword spotting for "Hey AURA".
 *                     A bundled Vosk (Kaldi) acoustic model is loaded and a
 *                     GRAMMAR-CONSTRAINED recognizer decodes the shared mic PCM
 *                     against the tiny grammar ["hey aura", "[unk]"]. This is
 *                     genuine on-device acoustic inference (mic PCM -> acoustic
 *                     model -> phrase + per-word confidence), NOT a free-form
 *                     speech-to-text transcript search. Detections carry the
 *                     model's real confidence; there is a native cooldown on
 *                     top of the Dart-side debouncer. If the model asset is
 *                     absent or fails to load we HONESTLY report `model_missing`
 *                     / `unavailable` and never fabricate a detection.
 *
 * mic_vad and wake share ONE AudioRecord + AEC/NS effects. The capture loop
 * runs while either consumer is active and is torn down when both stop.
 * RECORD_AUDIO is required; the bridge checks it and fails closed if absent.
 */
class AuraAudioBridge(
    private val context: Context,
    messenger: io.flutter.plugin.common.BinaryMessenger,
) {
    private val main = Handler(Looper.getMainLooper())

    // ── output_level ──
    private var visualizer: Visualizer? = null
    private var outputSink: EventChannel.EventSink? = null

    // ── shared mic capture ──
    private var audioRecord: AudioRecord? = null
    private var aec: AcousticEchoCanceler? = null
    private var ns: NoiseSuppressor? = null
    private var micThread: Thread? = null
    @Volatile private var captureRunning = false
    @Volatile private var micVadEnabled = false
    @Volatile private var wakeEnabled = false
    private var micSink: EventChannel.EventSink? = null

    // ── wake (Vosk acoustic KWS) ──
    private val wakeLock = Any()
    private var voskModel: Model? = null
    private var recognizer: Recognizer? = null
    private var wakeSink: EventChannel.EventSink? = null
    @Volatile private var modelState: String = "uninitialized"
    @Volatile private var lastWakeMs: Long = 0L

    init {
        // 1) output_level
        MethodChannel(messenger, "com.aura.aura_assistant/output_level")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> result.success(startOutputLevel())
                    "stop" -> { stopOutputLevel(); result.success(true) }
                    else -> result.notImplemented()
                }
            }
        EventChannel(messenger, "com.aura.aura_assistant/output_level.events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) { outputSink = sink }
                override fun onCancel(args: Any?) { outputSink = null }
            })

        // 2) mic_vad
        MethodChannel(messenger, "com.aura.aura_assistant/mic_vad")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> result.success(startMicVad())
                    "stop" -> { stopMicVad(); result.success(true) }
                    else -> result.notImplemented()
                }
            }
        EventChannel(messenger, "com.aura.aura_assistant/mic_vad.events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) { micSink = sink }
                override fun onCancel(args: Any?) { micSink = null }
            })

        // 3) wake
        MethodChannel(messenger, "com.aura.aura_assistant/wake")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> result.success(initializeWake())
                    "start" -> result.success(startWake())
                    "stop" -> { stopWake(); result.success(true) }
                    else -> result.notImplemented()
                }
            }
        EventChannel(messenger, "com.aura.aura_assistant/wake.events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) { wakeSink = sink }
                override fun onCancel(args: Any?) { wakeSink = null }
            })
    }

    private fun hasMicPermission(): Boolean =
        context.checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    // ───────────────────────── output_level ──────────────────────

    /** @return true if the Visualizer started and is emitting real RMS. */
    private fun startOutputLevel(): Boolean {
        if (!hasMicPermission()) return false
        if (visualizer != null) return true
        return try {
            // Session 0 = global output mix (what the device is playing).
            val v = Visualizer(0)
            v.captureSize = Visualizer.getCaptureSizeRange()[1].coerceAtMost(1024)
            v.setDataCaptureListener(
                object : Visualizer.OnDataCaptureListener {
                    override fun onWaveFormDataCapture(vis: Visualizer?, wave: ByteArray?, rate: Int) {
                        if (wave == null) return
                        // Bytes are unsigned 8-bit PCM centred at 128.
                        var sumSq = 0.0
                        for (b in wave) {
                            val centered = (b.toInt() and 0xFF) - 128
                            val norm = centered / 128.0
                            sumSq += norm * norm
                        }
                        val rms = sqrt(sumSq / wave.size)
                        // Light gain so quiet speech is visible; clamp 0..1.
                        val level = (rms * 2.2).coerceIn(0.0, 1.0)
                        main.post { outputSink?.success(level) }
                    }
                    override fun onFftDataCapture(vis: Visualizer?, fft: ByteArray?, rate: Int) {}
                },
                Visualizer.getMaxCaptureRate() / 2,
                true, // waveform
                false, // no fft
            )
            v.enabled = true
            visualizer = v
            true
        } catch (e: Throwable) {
            // RuntimeException on devices that forbid session-0 capture.
            stopOutputLevel()
            false
        }
    }

    private fun stopOutputLevel() {
        try { visualizer?.enabled = false } catch (_: Throwable) {}
        try { visualizer?.release() } catch (_: Throwable) {}
        visualizer = null
    }

    // ────────────────────── shared mic capture + AEC ────────────────

    private val sampleRate = 16000
    private val frameSamples = 512 // ~32ms @ 16kHz

    /** mic_vad start. @return map { started, aec }. */
    private fun startMicVad(): Map<String, Any> {
        micVadEnabled = true
        val ok = ensureCapture()
        if (!ok) micVadEnabled = false
        return mapOf("started" to ok, "aec" to aecStatusString())
    }

    private fun stopMicVad() {
        micVadEnabled = false
        stopCaptureIfIdle()
    }

    /**
     * Start (or reuse) the single shared AudioRecord capture loop. Idempotent:
     * returns true if a capture is running afterwards.
     */
    @Synchronized
    private fun ensureCapture(): Boolean {
        if (captureRunning) return true
        if (!hasMicPermission()) return false

        val minBuf = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBuf <= 0) return false
        val bufSize = maxOf(minBuf, frameSamples * 2 * 4)

        val record = try {
            AudioRecord(
                // VOICE_COMMUNICATION requests the platform voice pipeline,
                // which enables hardware AEC/AGC/NS on capable devices — this
                // is what stops AURA's own TTS output from self-waking the KWS.
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufSize,
            )
        } catch (e: Throwable) {
            null
        }
        if (record == null || record.state != AudioRecord.STATE_INITIALIZED) {
            try { record?.release() } catch (_: Throwable) {}
            return false
        }

        // Attach REAL AEC + NS effects to this capture session when available.
        try {
            if (AcousticEchoCanceler.isAvailable()) {
                aec = AcousticEchoCanceler.create(record.audioSessionId)
                aec?.enabled = true
            }
        } catch (_: Throwable) { aec = null }
        try {
            if (NoiseSuppressor.isAvailable()) {
                ns = NoiseSuppressor.create(record.audioSessionId)
                ns?.enabled = true
            }
        } catch (_: Throwable) { ns = null }

        audioRecord = record
        captureRunning = true
        record.startRecording()

        micThread = Thread {
            val buf = ShortArray(frameSamples)
            while (captureRunning) {
                val n = try { record.read(buf, 0, buf.size) } catch (_: Throwable) { -1 }
                if (n <= 0) continue

                // Consumer A: VAD (barge-in) — RMS + zero-crossing rate.
                if (micVadEnabled) {
                    var sumSq = 0.0
                    var crossings = 0
                    var prev = 0
                    for (i in 0 until n) {
                        val s = buf[i].toInt()
                        val v = s / 32768.0
                        sumSq += v * v
                        if (i > 0 && ((prev >= 0 && s < 0) || (prev < 0 && s >= 0))) crossings++
                        prev = s
                    }
                    val rms = sqrt(sumSq / n).coerceIn(0.0, 1.0)
                    val zcr = if (n > 1) crossings.toDouble() / (n - 1) else 0.0
                    val payload = mapOf("level" to rms, "zcr" to zcr)
                    main.post { micSink?.success(payload) }
                }

                // Consumer B: acoustic wake-word inference (grammar-constrained).
                if (wakeEnabled) {
                    feedWake(buf, n)
                }
            }
        }.also { it.isDaemon = true; it.name = "aura-mic-capture"; it.start() }
        return true
    }

    /** Tear down the shared capture only when NO consumer needs it. */
    @Synchronized
    private fun stopCaptureIfIdle() {
        if (micVadEnabled || wakeEnabled) return
        captureRunning = false
        try { micThread?.join(300) } catch (_: Throwable) {}
        micThread = null
        try { aec?.release() } catch (_: Throwable) {}
        try { ns?.release() } catch (_: Throwable) {}
        aec = null
        ns = null
        try { audioRecord?.stop() } catch (_: Throwable) {}
        try { audioRecord?.release() } catch (_: Throwable) {}
        audioRecord = null
    }

    private fun aecStatusString(): String = when {
        aec?.enabled == true -> "active"
        AcousticEchoCanceler.isAvailable() -> "supported"
        else -> "unavailable"
    }

    // ────────────────────── wake: Vosk acoustic KWS ─────────────────

    private val modelAssetDir = "vosk-model-small-en-us-0.15"
    private val wakePhrase = "hey aura"
    private val wakeGrammar = "[\"hey aura\", \"[unk]\"]"
    // Native pre-gate. The Dart WakeWordDebouncer applies a second (0.5)
    // threshold + cooldown on top of this.
    private val minConfidence = 0.55
    private val cooldownMs = 2000L

    /**
     * Load the bundled acoustic model (copying it out of assets to internal
     * storage on first run). Returns one of:
     *   "listening"      — model loaded, ready to spot the phrase
     *   "model_missing"  — no model asset bundled (honest, never faked)
     *   "unavailable"    — mic permission absent or model failed to load
     */
    private fun initializeWake(): String {
        synchronized(wakeLock) {
            if (modelState == "listening" && voskModel != null) return "listening"
            if (!hasMicPermission()) { modelState = "unavailable"; return modelState }
            if (!assetModelExists()) { modelState = "model_missing"; return modelState }
            return try {
                LibVosk.setLogLevel(LogLevel.WARNINGS)
                val dir = ensureModelUnpacked()
                voskModel = Model(dir.absolutePath)
                modelState = "listening"
                modelState
            } catch (e: Throwable) {
                voskModel = null
                modelState = "unavailable"
                modelState
            }
        }
    }

    /** Begin acoustic wake detection on the shared mic. */
    private fun startWake(): Boolean {
        synchronized(wakeLock) {
            if (modelState != "listening") {
                // Attempt a lazy initialize; caller may have skipped it.
                if (initializeWake() != "listening") return false
            }
            val model = voskModel ?: return false
            if (recognizer == null) {
                recognizer = try {
                    Recognizer(model, sampleRate.toFloat(), wakeGrammar).also {
                        it.setWords(true)
                    }
                } catch (e: Throwable) {
                    null
                }
            }
            if (recognizer == null) return false
            wakeEnabled = true
        }
        return ensureCapture()
    }

    private fun stopWake() {
        synchronized(wakeLock) {
            wakeEnabled = false
            try { recognizer?.close() } catch (_: Throwable) {}
            recognizer = null
        }
        stopCaptureIfIdle()
    }

    /** Feed one PCM frame to the recognizer and emit a real detection if the
     *  grammar phrase is decoded with sufficient confidence. */
    private fun feedWake(buf: ShortArray, n: Int) {
        val rec: Recognizer
        synchronized(wakeLock) {
            rec = recognizer ?: return
        }
        val finalized = try { rec.acceptWaveForm(buf, n) } catch (_: Throwable) { false }
        val json = try {
            if (finalized) rec.result else rec.partialResult
        } catch (_: Throwable) { return }
        // Only accept on a finalized result: it carries per-word confidences.
        if (!finalized) return
        val conf = phraseConfidence(json) ?: return
        if (conf < minConfidence) {
            // Reject low-confidence: reset so the next utterance starts clean.
            try { rec.reset() } catch (_: Throwable) {}
            return
        }
        val now = System.currentTimeMillis()
        if (now - lastWakeMs < cooldownMs) {
            try { rec.reset() } catch (_: Throwable) {}
            return
        }
        lastWakeMs = now
        try { rec.reset() } catch (_: Throwable) {}
        val payload = mapOf("confidence" to conf)
        main.post { wakeSink?.success(payload) }
    }

    /**
     * Parse a Vosk result JSON and return the average confidence of the words
     * that make up the wake phrase, or null if the phrase is not present.
     * Example: {"result":[{"conf":0.98,"word":"hey"},{"conf":0.95,"word":"aura"}],
     *           "text":"hey aura"}
     */
    private fun phraseConfidence(json: String?): Double? {
        if (json.isNullOrBlank()) return null
        return try {
            val obj = JSONObject(json)
            val text = obj.optString("text", "").trim().lowercase()
            if (!text.contains(wakePhrase)) return null
            val words = obj.optJSONArray("result") ?: return 1.0
            var sum = 0.0
            var count = 0
            for (i in 0 until words.length()) {
                val w = words.optJSONObject(i) ?: continue
                val word = w.optString("word", "").lowercase()
                if (word == "hey" || word == "aura") {
                    sum += w.optDouble("conf", 1.0)
                    count++
                }
            }
            if (count == 0) 1.0 else (sum / count).coerceIn(0.0, 1.0)
        } catch (_: Throwable) {
            null
        }
    }

    // ── model asset helpers ──

    private fun assetModelExists(): Boolean = try {
        val entries = context.assets.list(modelAssetDir)
        entries != null && entries.isNotEmpty()
    } catch (_: Throwable) { false }

    /**
     * Copy the model tree out of the APK assets into internal storage (once)
     * and return the destination directory. Vosk's Model() requires a real
     * filesystem path, so bundled assets must be unpacked first.
     */
    private fun ensureModelUnpacked(): File {
        val dest = File(context.filesDir, modelAssetDir)
        val marker = File(dest, ".unpacked")
        if (marker.exists()) return dest
        if (dest.exists()) dest.deleteRecursively()
        dest.mkdirs()
        copyAssetDir(modelAssetDir, dest)
        try { marker.createNewFile() } catch (_: Throwable) {}
        return dest
    }

    private fun copyAssetDir(assetPath: String, destDir: File) {
        val children = context.assets.list(assetPath) ?: emptyArray()
        if (children.isEmpty()) {
            // Leaf file.
            destDir.parentFile?.mkdirs()
            context.assets.open(assetPath).use { input ->
                destDir.outputStream().use { output -> input.copyTo(output) }
            }
            return
        }
        destDir.mkdirs()
        for (child in children) {
            val childAsset = "$assetPath/$child"
            val grandChildren = try { context.assets.list(childAsset) } catch (_: Throwable) { null }
            val childDest = File(destDir, child)
            if (grandChildren != null && grandChildren.isNotEmpty()) {
                copyAssetDir(childAsset, childDest)
            } else {
                childDest.parentFile?.mkdirs()
                context.assets.open(childAsset).use { input ->
                    childDest.outputStream().use { output -> input.copyTo(output) }
                }
            }
        }
    }

    fun dispose() {
        stopOutputLevel()
        micVadEnabled = false
        wakeEnabled = false
        stopCaptureIfIdle()
        synchronized(wakeLock) {
            try { recognizer?.close() } catch (_: Throwable) {}
            recognizer = null
            try { voskModel?.close() } catch (_: Throwable) {}
            voskModel = null
            modelState = "uninitialized"
        }
    }
}
