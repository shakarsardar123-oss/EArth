package com.texo.texo

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import org.json.JSONObject
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.nio.FloatBuffer
import java.nio.LongBuffer
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

class VekolTtsBridge(
    private val context: Context
) {
    companion object {
        private const val MODEL_PATH = "vekol/model.onnx"
        private const val CONFIG_PATH = "vekol/model.onnx.json"
        private const val SAMPLE_RATE = 22050
        // Voice character. noise_w low = flat, robotic rhythm; 0.8 is Piper's default.
        private const val NOISE_SCALE = 0.667f
        private const val LENGTH_SCALE = 1.0f
        private const val NOISE_W = 0.8f
        private const val MAX_CHUNK = 70
        private const val GAP_SECONDS = 0.13f
    }

    private val ortEnvironment = OrtEnvironment.getEnvironment()
    private val session: OrtSession
    private val phonemeMap = mutableMapOf<String, Int>()
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    @Volatile
    private var stopped = false

    @Volatile
    private var audioTrack: AudioTrack? = null

    init {
        val modelPath = materializeModel()

        session = ortEnvironment.createSession(
            modelPath,
            OrtSession.SessionOptions()
        )

        val configText = context.assets.open(CONFIG_PATH)
            .bufferedReader(Charsets.UTF_8)
            .use { it.readText() }

        val config = JSONObject(configText)
        val map = config.getJSONObject("phoneme_id_map")

        val keys = map.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val values = map.getJSONArray(key)
            if (values.length() > 0) {
                phonemeMap[key] = values.getInt(0)
            }
        }
    }

    private fun materializeModel(): String {
        val out = java.io.File(context.filesDir, MODEL_PATH)
        out.parentFile?.mkdirs()
        val expected = context.assets.open(MODEL_PATH).use { it.available().toLong() }
        if (expected > 0L && out.exists() && out.length() == expected) {
            return out.absolutePath
        }
        val tmp = java.io.File(out.parentFile, out.name + ".tmp")
        context.assets.open(MODEL_PATH).use { input ->
            tmp.outputStream().use { output -> input.copyTo(output, 1024 * 1024) }
        }
        if (out.exists()) out.delete()
        if (!tmp.renameTo(out)) {
            throw java.io.IOException("Could not install TTS model")
        }
        return out.absolutePath
    }

    private fun toast(msg: String) {
        TexoLog.log(context, msg)
    }

    fun isReady(): Boolean = phonemeMap.isNotEmpty()

    fun stop() {
        stopped = true

        synchronized(this) {
            audioTrack?.let {
                try {
                    it.pause()
                    it.flush()
                    it.stop()
                } catch (_: Throwable) {
                }

                try {
                    it.release()
                } catch (_: Throwable) {
                }
            }

            audioTrack = null
        }
    }

    fun speak(text: String, onComplete: (Throwable?) -> Unit) {
        toast("TTS speak: ${text.length} chars")
        stop()

        stopped = false

        executor.execute {
            try {
                speakBlocking(text)

                if (!stopped) {
                    onComplete(null)
                } else {
                    onComplete(null)
                }
            } catch (t: Throwable) {
                toast("TTS error: ${t::class.java.simpleName}: ${t.message}")
                onComplete(t)
            }
        }
    }

    private fun speakBlocking(text: String) {
        val chunks = splitChunks(replaceNumbers(normalize(text.trim())))
        if (chunks.isEmpty()) return

        val track = openTrack()
        synchronized(this) { audioTrack = track }

        try {
            track.play()
            var written = 0L
            for ((i, chunk) in chunks.withIndex()) {
                if (stopped) break
                val audio = synthesize(chunk)
                if (audio.isEmpty()) {
                    toast("TTS: empty audio for a chunk")
                    continue
                }
                written += writePcm(track, toPcm(audio))
                if (i < chunks.size - 1 && !stopped) {
                    written += writePcm(track, ShortArray((SAMPLE_RATE * GAP_SECONDS).toInt()))
                }
            }
            if (!stopped) {
                var waited = 0
                while (!stopped && waited < 60000) {
                    val pos = try {
                        track.playbackHeadPosition.toLong()
                    } catch (_: Throwable) {
                        break
                    }
                    if (pos >= written) break
                    Thread.sleep(10)
                    waited += 10
                }
            }
        } finally {
            try { track.stop() } catch (_: Throwable) {}
            try { track.release() } catch (_: Throwable) {}
            synchronized(this) {
                if (audioTrack === track) audioTrack = null
            }
        }
    }

    private fun synthesize(text: String): FloatArray {
        val ids = buildIds(text)
        if (ids.size <= 4) {
            toast("TTS: no known letters in text")
            return FloatArray(0)
        }

        val input = OnnxTensor.createTensor(
            ortEnvironment, LongBuffer.wrap(ids), longArrayOf(1, ids.size.toLong())
        )
        val inputLengths = OnnxTensor.createTensor(
            ortEnvironment, LongBuffer.wrap(longArrayOf(ids.size.toLong())), longArrayOf(1)
        )
        val scales = OnnxTensor.createTensor(
            ortEnvironment,
            FloatBuffer.wrap(floatArrayOf(NOISE_SCALE, LENGTH_SCALE, NOISE_W)),
            longArrayOf(3)
        )
        val sid = OnnxTensor.createTensor(
            ortEnvironment, LongBuffer.wrap(longArrayOf(0L)), longArrayOf(1)
        )

        try {
            val audio = session.run(
                mapOf(
                    "input" to input,
                    "input_lengths" to inputLengths,
                    "scales" to scales,
                    "sid" to sid
                )
            ).use { result ->
                if (stopped) FloatArray(0) else extractAudio(result[0].value)
            }
            return audio
        } finally {
            input.close()
            inputLengths.close()
            scales.close()
            sid.close()
        }
    }

    // ---- text preparation -----------------------------------------------------

    private val onesWords = arrayOf("سفر", "یەک", "دوو", "سێ", "چوار", "پێنج", "شەش", "حەوت", "هەشت", "نۆ")
    private val teenWords = arrayOf("دە", "یازدە", "دوازدە", "سیازدە", "چواردە", "پازدە", "شازدە", "حەڤدە", "هەژدە", "نۆزدە")
    private val tensWords = arrayOf("", "", "بیست", "سی", "چل", "پەنجا", "شەست", "حەفتا", "هەشتا", "نەوەد")

    private fun numberToKurdish(n: Int): String {
        if (n < 10) return onesWords[n]
        if (n < 20) return teenWords[n - 10]
        if (n < 100) {
            val t = n / 10
            val o = n % 10
            return if (o == 0) tensWords[t] else tensWords[t] + " و " + onesWords[o]
        }
        if (n < 1000) {
            val h = n / 100
            val r = n % 100
            val word = if (h == 1) "سەد" else onesWords[h] + " سەد"
            return if (r == 0) word else word + " و " + numberToKurdish(r)
        }
        if (n < 1000000) {
            val th = n / 1000
            val r = n % 1000
            val word = if (th == 1) "هەزار" else numberToKurdish(th) + " هەزار"
            return if (r == 0) word else word + " و " + numberToKurdish(r)
        }
        return n.toString()
    }

    private fun replaceNumbers(text: String): String =
        Regex("[0-9]+").replace(text) { m ->
            val v = m.value.toIntOrNull()
            if (v == null || v >= 1000000) m.value else numberToKurdish(v)
        }

    /** Short pieces sound natural; one long run-on sentence turns robotic. */
    private fun splitChunks(text: String): List<String> {
        val out = ArrayList<String>()
        val sentences = text.split(Regex("(?<=[.!?؟])\\s+|\\n+"))
            .map { it.trim() }
            .filter { it.isNotEmpty() }

        for (sentence in sentences) {
            val last = sentence.last()
            val ending = if (last == '!' || last == '؟' || last == '?') (if (last == '?') '؟' else last) else '.'
            val pieces = ArrayList<String>()
            if (sentence.length <= MAX_CHUNK) {
                pieces.add(sentence)
            } else {
                var buf = ""
                val parts = sentence.split(Regex("(?<=[،؛,;:])\\s+"))
                for (part in parts) {
                    val sub = if (part.length > MAX_CHUNK + 20) {
                        val words = part.split(" ")
                        val acc = ArrayList<String>()
                        var cur = ""
                        for (w in words) {
                            if (cur.isNotEmpty() && cur.length + w.length + 1 > MAX_CHUNK) {
                                acc.add(cur); cur = w
                            } else {
                                cur = if (cur.isEmpty()) w else "$cur $w"
                            }
                        }
                        if (cur.isNotEmpty()) acc.add(cur)
                        acc
                    } else listOf(part)
                    for (piece in sub) {
                        if (buf.isNotEmpty() && buf.length + piece.length + 1 > MAX_CHUNK) {
                            pieces.add(buf); buf = piece
                        } else {
                            buf = if (buf.isEmpty()) piece else "$buf $piece"
                        }
                    }
                }
                if (buf.isNotBlank()) pieces.add(buf)
            }
            for ((i, piece) in pieces.withIndex()) {
                val clean = piece.trim().trimEnd('.', '!', '?', '؟', '،', '؛', ',', ';', ':').trim()
                if (clean.isEmpty()) continue
                out.add(clean + if (i == pieces.size - 1) ending else '.')
            }
        }
        return out
    }

    private fun buildIds(text: String): LongArray {
        // Same as the reference script: decompose (NFD) so letters such as
        // U+0626, which is not in the map as one char, become two in-map
        // characters instead of being dropped.
        val normalized = java.text.Normalizer.normalize(
            normalize(text),
            java.text.Normalizer.Form.NFD,
        )

        val ids = ArrayList<Long>()
        val pad = phonemeMap["_"] ?: 0
        val bos = phonemeMap["^"] ?: 1
        val eos = phonemeMap["$"] ?: 2

        ids.add(bos.toLong())
        ids.add(pad.toLong())

        for (char in normalized) {
            val id = phonemeMap[char.toString()]
            if (id != null) {
                ids.add(id.toLong())
                ids.add(pad.toLong())
            }
        }

        ids.add(eos.toLong())

        return ids.toLongArray()
    }

    private fun normalize(input: String): String {
        var text = input

        val replacements = mapOf(
            'ك' to 'ک',
            'ھ' to 'ه',
            'ہ' to 'ه',
            'ۀ' to 'ە',
            'ة' to 'ە',
            'ى' to 'ی',
            'ﻯ' to 'ی',
            'ﺉ' to 'ئ',
            'ٸ' to 'ئ',
            'ؤ' to 'و',
            'أ' to 'ا',
            'إ' to 'ا',
            'آ' to 'ا',
            'ٱ' to 'ا',
            'ڭ' to 'گ',
            '\u200C' to null,
            '\u200D' to null,
            'ـ' to null,
            '“' to '"',
            '”' to '"',
            '’' to '\'',
            '‘' to '\'',
            '—' to '-',
            '–' to '-',
            '…' to '.'
        )

        val builder = StringBuilder()

        for (c in text) {
            val replacement = replacements[c]

            when {
                replacements.containsKey(c) && replacement == null -> Unit
                replacement != null -> builder.append(replacement)
                else -> builder.append(c)
            }
        }

        text = builder.toString()

        val digits = mapOf(
            '٠' to '0', '١' to '1', '٢' to '2', '٣' to '3',
            '٤' to '4', '٥' to '5', '٦' to '6', '٧' to '7',
            '٨' to '8', '٩' to '9',
            '۰' to '0', '۱' to '1', '۲' to '2', '۳' to '3',
            '۴' to '4', '۵' to '5', '۶' to '6', '۷' to '7',
            '۸' to '8', '۹' to '9'
        )

        text = buildString {
            for (c in text) {
                append(digits[c] ?: c)
            }
        }

        return text
    }

    private fun extractAudio(value: Any): FloatArray {
        val a = value as? Array<*> ?: return FloatArray(0)

        var current: Any? = a
        while (current is Array<*>) {
            if (current.isEmpty()) return FloatArray(0)
            current = current[0]
        }

        return when (current) {
            is FloatArray -> current
            else -> FloatArray(0)
        }
    }

    private fun openTrack(): AudioTrack {
        val minBuffer = AudioTrack.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val bufferSize = max(minBuffer * 2, SAMPLE_RATE) // about 1 second

        return AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(SAMPLE_RATE)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
    }

    /** Float samples to 16-bit PCM with a 6 ms fade at both ends (no clicks). */
    private fun toPcm(samples: FloatArray): ShortArray {
        val pcm = ShortArray(samples.size)
        val fade = (SAMPLE_RATE * 0.006f).toInt().coerceAtMost(samples.size / 2)
        for (i in samples.indices) {
            var v = samples[i].coerceIn(-1f, 1f)
            if (i < fade) v *= i / fade.toFloat()
            else if (i >= samples.size - fade) v *= (samples.size - 1 - i) / fade.toFloat()
            pcm[i] = (v * 32767f).roundToInt().toShort()
        }
        return pcm
    }

    private fun writePcm(track: AudioTrack, pcm: ShortArray): Long {
        var offset = 0
        while (offset < pcm.size && !stopped) {
            val n = track.write(pcm, offset, pcm.size - offset)
            if (n <= 0) break
            offset += n
        }
        return offset.toLong()
    }

    fun dispose() {
        stop()
        executor.shutdownNow()
        session.close()
    }
}
