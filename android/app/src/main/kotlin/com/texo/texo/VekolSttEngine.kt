package com.texo.texo

import android.content.Context
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OnnxValue
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Offline Sorani STT engine for the Vekol Whisper-base ONNX model.
 *
 * Pipeline:
 * PCM 16 kHz mono -> Whisper log-mel -> encoder ->
 * no-cache decoder -> GPT-2 byte-level token decoding -> Sorani text.
 *
 * CPU-only. Decoder intentionally starts with no-cache decoding.
 */
class VekolSttEngine(
    private val context: Context,
) {
    companion object {
        private const val ENCODER_PATH =
            "vekol_stt/encoder_model.onnx"
        private const val DECODER_PATH =
            "vekol_stt/decoder_model_merged.onnx"

        private const val SAMPLE_RATE = 16000
        private const val N_FFT = 400
        private const val HOP_LENGTH = 160
        private const val N_MELS = 80
        private const val N_FRAMES = 3000
        private const val N_SAMPLES = 480000

        private const val MEL_FMIN = 0.0
        private const val MEL_FMAX = 8000.0
    }

    private val ortEnvironment = OrtEnvironment.getEnvironment()

    private val encoderSession: OrtSession
    private val decoderSession: OrtSession

    private val executor: ExecutorService =
        Executors.newSingleThreadExecutor()

    @Volatile
    private var closed = false

    init {
        // Load models from a file path: readBytes() put ~280 MB (plus
        // copies) on the Java heap and can throw OutOfMemoryError.
        encoderSession = ortEnvironment.createSession(
            materializeAsset(ENCODER_PATH),
            sessionOptions(),
        )

        decoderSession = ortEnvironment.createSession(
            materializeAsset(DECODER_PATH),
            sessionOptions(),
        )
    }

    private fun materializeAsset(assetPath: String): String {
        val out = java.io.File(context.filesDir, assetPath)
        out.parentFile?.mkdirs()

        val expected =
            context.assets.open(assetPath).use { it.available().toLong() }
        if (expected > 0L && out.exists() && out.length() == expected) {
            return out.absolutePath
        }

        val tmp = java.io.File(out.parentFile, out.name + ".tmp")
        context.assets.open(assetPath).use { input ->
            tmp.outputStream().use { output ->
                input.copyTo(output, 1024 * 1024)
            }
        }
        if (out.exists()) out.delete()
        if (!tmp.renameTo(out)) {
            throw java.io.IOException("Could not install model: $assetPath")
        }
        return out.absolutePath
    }

    fun isReady(): Boolean = !closed

    fun transcribe(
        samples: ShortArray,
        onResult: (String) -> Unit,
        onError: (Throwable) -> Unit,
    ) {
        if (closed) {
            onError(IllegalStateException("Vekol STT engine is closed"))
            return
        }

        executor.execute {
            try {
                val t0 = System.nanoTime()
                val text = transcribeBlocking(samples)
                val ms = (System.nanoTime() - t0) / 1_000_000
                TexoLog.log(context, "STT: ${samples.size / 16} ms audio -> ${ms} ms [${text}]")
                onResult(text)
            } catch (t: Throwable) {
                onError(t)
            }
        }
    }

    @Volatile
    private var maxNewTokens = 40

    /** Boost quiet phone-mic audio so Whisper sees a normal level. */
    private fun normalizeLevel(src: ShortArray): ShortArray {
        var peak = 0
        for (s in src) {
            val a = kotlin.math.abs(s.toInt())
            if (a > peak) peak = a
        }
        if (peak < 200) return src
        val gain = (0.9f * 32767f / peak).coerceIn(1f, 12f)
        if (gain < 1.05f) return src
        return ShortArray(src.size) { i ->
            (src[i] * gain).toInt().coerceIn(-32768, 32767).toShort()
        }
    }

    private fun transcribeBlocking(samples: ShortArray): String {
        maxNewTokens = (12 + 10 * (samples.size / 16000.0)).toInt().coerceIn(16, 80)
        val features = whisperLogMel(normalizeLevel(samples))

        val featureData = Array(1) {
            Array(N_MELS) { mel ->
                FloatArray(N_FRAMES) { frame ->
                    features[mel * N_FRAMES + frame]
                }
            }
        }

        OnnxTensor.createTensor(
            ortEnvironment,
            featureData,
        ).use { inputTensor ->

            val inputs = mapOf(
                "input_features" to inputTensor,
            )

            encoderSession.run(inputs).use { result ->
                // Fast path: decode with the KV cache, reading the encoder output
                // in place (no copy). The slow path below is the fallback.
                val encoderTensor = result[0] as? OnnxTensor
                if (encoderTensor != null) {
                    try {
                        return decodeCached(encoderTensor)
                    } catch (t: Throwable) {
                        TexoLog.log(context, "STT: cached decoder failed (" + t.javaClass.simpleName + ": " + t.message + "), using the slow path")
                    }
                }
                val hidden = result[0].value

                if (hidden !is Array<*>) {
                    throw IllegalStateException(
                        "Unexpected encoder output type: " +
                            hidden?.javaClass?.name,
                    )
                }

                @Suppress("UNCHECKED_CAST")
                val hidden3d = hidden as Array<Array<FloatArray>>

                if (hidden3d.size != 1 ||
                    hidden3d[0].size != 1500 ||
                    hidden3d[0][0].size != 512
                ) {
                    throw IllegalStateException(
                        "Unexpected encoder output shape: " +
                            "${hidden3d.size} x " +
                            "${hidden3d[0].size} x " +
                            "${hidden3d[0][0].size}",
                    )
                }

                return decodeNoCache(hidden3d)
            }
        }
    }

    /**
     * WhisperFeatureExtractor-compatible preprocessing.
     *
     * Output is flattened [80 * 3000], row-major.
     */
    private fun whisperLogMel(samples: ShortArray): FloatArray {
        val audio = FloatArray(N_SAMPLES)

        val copyCount = min(samples.size, N_SAMPLES)

        for (i in 0 until copyCount) {
            audio[i] = samples[i] / 32768.0f
        }

        val padded = FloatArray(
            N_SAMPLES + N_FFT,
        )

        val pad = N_FFT / 2

        for (i in 0 until N_FFT) {
            val src = when {
                i < pad ->
                    min(
                        N_SAMPLES - 1,
                        pad - i,
                    )

                i >= N_FFT - pad ->
                    max(
                        0,
                        N_SAMPLES - 1 -
                            (i - (N_FFT - pad) + 1),
                    )

                else -> i - pad
            }

            padded[i] = audio[src]
        }

        System.arraycopy(
            audio,
            0,
            padded,
            pad,
            N_SAMPLES,
        )

        val lastStart = (N_FRAMES - 1) * HOP_LENGTH

        for (i in 0 until N_FFT) {
            val src = min(
                N_SAMPLES - 1,
                lastStart + i - pad,
            )

            if (lastStart + N_FFT + i < padded.size) padded[lastStart + N_FFT + i] =
                if (src >= 0) audio[src] else 0.0f
        }

        val window = FloatArray(N_FFT)

        for (i in 0 until N_FFT) {
            window[i] =
                (0.5 - 0.5 * cos(
                    2.0 * PI * i / N_FFT,
                )).toFloat()
        }

        val melFilters =
            buildMelFilters()

        val output = FloatArray(
            N_MELS * N_FRAMES,
        )

        val real = DoubleArray(N_FFT)
        val imag = DoubleArray(N_FFT)
        val power = DoubleArray(
            N_FFT / 2 + 1,
        )
        val mel = DoubleArray(N_MELS)

        for (frame in 0 until N_FRAMES) {
            val start = frame * HOP_LENGTH

            for (i in 0 until N_FFT) {
                real[i] =
                    padded[start + i].toDouble() *
                        window[i]

                imag[i] = 0.0
            }

            fftFast(real, imag)

            for (k in power.indices) {
                power[k] =
                    real[k] * real[k] +
                        imag[k] * imag[k]
            }

            for (m in 0 until N_MELS) {
                var sum = 0.0

                val filter = melFilters[m]

                for (k in power.indices) {
                    val weight = filter[k]

                    if (weight != 0.0) {
                        sum += power[k] * weight
                    }
                }

                mel[m] = max(sum, 1e-10)
            }

            var maxLog = Double.NEGATIVE_INFINITY

            for (m in 0 until N_MELS) {
                val value = log10(mel[m])

                mel[m] = value

                if (value > maxLog) {
                    maxLog = value
                }
            }

            val floor = Double.NEGATIVE_INFINITY

            for (m in 0 until N_MELS) {
                val clipped = max(
                    mel[m],
                    floor,
                )

                output[m * N_FRAMES + frame] =
                    ((clipped + 4.0) / 4.0).toFloat()
            }
        }

        // Whisper: clamp to (global max - 8.0), in scaled units that is max - 2.
        var gMax = Float.NEGATIVE_INFINITY
        for (v in output) if (v > gMax) gMax = v
        val gFloor = gMax - 2.0f
        for (i in output.indices) if (output[i] < gFloor) output[i] = gFloor
        return output
    }

        /** Whisper-compatible Slaney mel filterbank (norm = slaney). */
    private fun buildMelFilters(): Array<DoubleArray> {
        val bins = N_FFT / 2 + 1
        val fSp = 200.0 / 3.0
        val minLogHz = 1000.0
        val minLogMel = minLogHz / fSp
        val logStep = ln(6.4) / 27.0
        fun hz2mel(f: Double): Double =
            if (f >= minLogHz) minLogMel + ln(f / minLogHz) / logStep else f / fSp
        fun mel2hz(m: Double): Double =
            if (m >= minLogMel) minLogHz * exp(logStep * (m - minLogMel)) else fSp * m
        val melMin = hz2mel(0.0)
        val melMax = hz2mel(8000.0)
        val pts = DoubleArray(N_MELS + 2) {
            mel2hz(melMin + (melMax - melMin) * it / (N_MELS + 1))
        }
        val freqs = DoubleArray(bins) { it * SAMPLE_RATE.toDouble() / N_FFT }
        val filters = Array(N_MELS) { DoubleArray(bins) }
        for (m in 0 until N_MELS) {
            val lo = pts[m]; val ce = pts[m + 1]; val hi = pts[m + 2]
            val enorm = 2.0 / (hi - lo)
            for (k in 0 until bins) {
                val f = freqs[k]
                val up = (f - lo) / (ce - lo)
                val down = (hi - f) / (hi - ce)
                filters[m][k] = max(0.0, min(up, down)) * enorm
            }
        }
        return filters
    }

    private fun buildMelFiltersOld(): Array<DoubleArray> {
        val bins = N_FFT / 2 + 1

        val filters = Array(N_MELS) {
            DoubleArray(bins)
        }

        val melMin =
            hzToMel(MEL_FMIN)

        val melMax =
            hzToMel(MEL_FMAX)

        val points = DoubleArray(N_MELS + 2)

        for (i in points.indices) {
            points[i] =
                melMin +
                    (melMax - melMin) *
                    i / (N_MELS + 1)
        }

        val hzPoints = DoubleArray(points.size) {
            melToHz(points[it])
        }

        val binPoints = IntArray(hzPoints.size) {
            floorToInt(
                (N_FFT + 1) *
                    hzPoints[it] /
                    SAMPLE_RATE,
            ).coerceIn(0, bins - 1)
        }

        for (m in 0 until N_MELS) {
            val left = binPoints[m]
            val center = binPoints[m + 1]
            val right = binPoints[m + 2]

            if (center > left) {
                for (k in left until center) {
                    filters[m][k] =
                        (k - left).toDouble() /
                            (center - left)
                }
            }

            if (right > center) {
                for (k in center until right) {
                    filters[m][k] =
                        (right - k).toDouble() /
                            (right - center)
                }
            }
        }

        return filters
    }

    private fun hzToMel(hz: Double): Double {
        return 1127.0 *
            ln(1.0 + hz / 700.0)
    }

    private fun melToHz(mel: Double): Double {
        return 700.0 *
            (exp(mel / 1127.0) - 1.0)
    }

    private fun floorToInt(value: Double): Int {
        return kotlin.math.floor(value).toInt()
    }

    /**
     * In-place radix-2 FFT is not applicable to N=400.
     *
     * This mixed-radix implementation factors:
     * 400 = 16 * 25.
     */
    private fun fft(
        real: DoubleArray,
        imag: DoubleArray,
    ) {
        val n = real.size
        if (n != 400) {
            throw IllegalArgumentException("Expected 400-point FFT")
        }

        // 400 = 16 * 25.
        // Direct 400-point DFT is far too slow for 3000 Whisper frames.
        // Use a mixed-radix Cooley-Tukey decomposition.
        val outReal = DoubleArray(n)
        val outImag = DoubleArray(n)

        val n1 = 16
        val n2 = 25

        for (k1 in 0 until n1) {
            for (k2 in 0 until n2) {
                var sumReal = 0.0
                var sumImag = 0.0

                for (j1 in 0 until n1) {
                    for (j2 in 0 until n2) {
                        val t = j1 * n2 + j2
                        val k = k1 * n2 + k2

                        val angle =
                            -2.0 * PI * k * t / n

                        val c = cos(angle)
                        val s = sin(angle)

                        sumReal +=
                            real[t] * c -
                                imag[t] * s

                        sumImag +=
                            real[t] * s +
                                imag[t] * c
                    }
                }

                val index = k1 * n2 + k2
                outReal[index] = sumReal
                outImag[index] = sumImag
            }
        }

        System.arraycopy(outReal, 0, real, 0, n)
        System.arraycopy(outImag, 0, imag, 0, n)
    }

        private val twCos = DoubleArray(400) { cos(2.0 * PI * it / 400) }
    private val twSin = DoubleArray(400) { -sin(2.0 * PI * it / 400) }

    /** DFT of a real 400-sample frame, bins 0..200 only, table-based. */
    private fun fftFast(real: DoubleArray, imag: DoubleArray) {
        val n = 400
        var any = false
        for (t in 0 until n) { if (real[t] != 0.0) { any = true; break } }
        if (!any) { java.util.Arrays.fill(imag, 0.0); return }
        val outR = DoubleArray(201)
        val outI = DoubleArray(201)
        for (k in 0..200) {
            var sr = 0.0
            var si = 0.0
            var idx = 0
            for (t in 0 until n) {
                val r = real[t]
                sr += r * twCos[idx]
                si += r * twSin[idx]
                idx += k
                if (idx >= n) idx -= n
            }
            outR[k] = sr
            outI[k] = si
        }
        for (k in 0..200) { real[k] = outR[k]; imag[k] = outI[k] }
    }


    /**
     * Greedy decoding WITH the KV cache of the merged decoder. The first pass
     * (the 4 prompt tokens) also produces the encoder keys/values ONCE; every
     * next step feeds a single token and reuses the cache. The old no-cache
     * loop recomputed the encoder keys/values for every token (about 9 GFLOP
     * per token), which is why a 3 s clip needed 19 s.
     */
    private fun decodeCached(encoderTensor: OnnxTensor): String {
        val t0 = System.nanoTime()
        val tokenIds = mutableListOf(
            50258L, // <|startoftranscript|>
            50300L, // <|fa|>
            50359L, // <|transcribe|>
            50363L, // <|notimestamps|>
        )
        val maxTokens = 4 + maxNewTokens
        val eosToken = 50257L
        val layers = 6

        val decoderKv = arrayOfNulls<OnnxValue>(layers * 2)
        val encoderKv = arrayOfNulls<OnnxValue>(layers * 2)
        var encoderHolder: OrtSession.Result? = null
        var previous: OrtSession.Result? = null

        try {
            while (tokenIds.size < maxTokens) {
                val first = encoderHolder == null
                val ids =
                    if (first) LongArray(tokenIds.size) { tokenIds[it] }
                    else longArrayOf(tokenIds[tokenIds.size - 1])
                val pos =
                    if (first) LongArray(tokenIds.size) { it.toLong() }
                    else longArrayOf((tokenIds.size - 1).toLong())

                val created = ArrayList<OnnxTensor>()
                val inputs = HashMap<String, OnnxTensor>()
                try {
                    val idsTensor = OnnxTensor.createTensor(ortEnvironment, arrayOf(ids))
                    created.add(idsTensor)
                    inputs["input_ids"] = idsTensor
                    inputs["encoder_hidden_states"] = encoderTensor

                    val cacheFlag = OnnxTensor.createTensor(ortEnvironment, booleanArrayOf(!first))
                    created.add(cacheFlag)
                    inputs["use_cache_branch"] = cacheFlag

                    val posTensor = OnnxTensor.createTensor(ortEnvironment, pos)
                    created.add(posTensor)
                    inputs["cache_position"] = posTensor

                    for (layer in 0 until layers) {
                        if (first) {
                            for (name in listOf("decoder.key", "decoder.value", "encoder.key", "encoder.value")) {
                                val t = placeholderKvTensor()
                                created.add(t)
                                inputs["past_key_values.$layer.$name"] = t
                            }
                        } else {
                            inputs["past_key_values.$layer.decoder.key"] = decoderKv[layer * 2] as OnnxTensor
                            inputs["past_key_values.$layer.decoder.value"] = decoderKv[layer * 2 + 1] as OnnxTensor
                            inputs["past_key_values.$layer.encoder.key"] = encoderKv[layer * 2] as OnnxTensor
                            inputs["past_key_values.$layer.encoder.value"] = encoderKv[layer * 2 + 1] as OnnxTensor
                        }
                    }

                    val result = decoderSession.run(inputs)

                    val outs = HashMap<String, OnnxValue>()
                    for (e in result) outs[e.key] = e.value

                    for (layer in 0 until layers) {
                        decoderKv[layer * 2] = outs["present.$layer.decoder.key"]
                        decoderKv[layer * 2 + 1] = outs["present.$layer.decoder.value"]
                        if (first) {
                            encoderKv[layer * 2] = outs["present.$layer.encoder.key"]
                            encoderKv[layer * 2 + 1] = outs["present.$layer.encoder.value"]
                        }
                    }

                    // Keep the first result (it owns the encoder cache) until the
                    // end; free the older decoder-cache owner.
                    if (first) {
                        encoderHolder = result
                    } else {
                        val old = previous
                        if (old != null && old !== encoderHolder) {
                            try { old.close() } catch (_: Throwable) {}
                        }
                    }
                    previous = result

                    val logitsTensor = (outs["logits"] ?: result[0]) as OnnxTensor
                    @Suppress("UNCHECKED_CAST")
                    val logits = logitsTensor.value as Array<Array<FloatArray>>
                    val lastLogits = logits[0][logits[0].size - 1]

                    if (tokenIds.size == 4) {
                        var mx = Float.NEGATIVE_INFINITY
                        for (v in lastLogits) if (v > mx) mx = v
                        var sum = 0.0
                        for (v in lastLogits) sum += Math.exp((v - mx).toDouble())
                        val pNoSpeech = Math.exp((lastLogits[50362] - mx).toDouble()) / sum
                        if (pNoSpeech > 0.8) return ""
                        lastLogits[220] = Float.NEGATIVE_INFINITY
                        lastLogits[50257] = Float.NEGATIVE_INFINITY
                    }
                    for (i in 50258 until lastLogits.size) lastLogits[i] = Float.NEGATIVE_INFINITY

                    var bestId = 0
                    var bestValue = Float.NEGATIVE_INFINITY
                    for (i in lastLogits.indices) {
                        if (lastLogits[i] > bestValue) {
                            bestValue = lastLogits[i]
                            bestId = i
                        }
                    }

                    val nextToken = bestId.toLong()
                    if (nextToken == eosToken) break
                    tokenIds.add(nextToken)

                    if (tokenIds.size >= 12) {
                        val tail = tokenIds.subList(tokenIds.size - 8, tokenIds.size)
                        if (tail.toSet().size <= 2) {
                            val text = decodeTokens(tokenIds.subList(0, tokenIds.size - 6))
                            TexoLog.log(context, "STT: cached decode " + (tokenIds.size - 4) + " tokens, " + ((System.nanoTime() - t0) / 1_000_000) + " ms")
                            return text
                        }
                    }
                } finally {
                    for (t in created) {
                        try { t.close() } catch (_: Throwable) {}
                    }
                }
            }
            val text = decodeTokens(tokenIds)
            TexoLog.log(context, "STT: cached decode " + (tokenIds.size - 4) + " tokens, " + ((System.nanoTime() - t0) / 1_000_000) + " ms")
            return text
        } finally {
            val prev = previous
            if (prev != null) {
                try { prev.close() } catch (_: Throwable) {}
            }
            val holder = encoderHolder
            if (holder != null && holder !== prev) {
                try { holder.close() } catch (_: Throwable) {}
            }
        }
    }

    private fun sessionOptions(): OrtSession.SessionOptions {
        val options = OrtSession.SessionOptions()
        try {
            val cores = Runtime.getRuntime().availableProcessors()
            options.setIntraOpNumThreads((cores / 2).coerceIn(2, 4))
        } catch (_: Throwable) {
        }
        try {
            options.setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
        } catch (_: Throwable) {
        }
        return options
    }

    private fun decodeNoCache(
        encoderHidden: Array<Array<FloatArray>>,
    ): String {
        val tokenIds = mutableListOf(
            50258L, // <|startoftranscript|>
            50300L, // <|fa|>
            50359L, // <|transcribe|>
            50363L, // <|notimestamps|>
        )

        val maxTokens = 4 + maxNewTokens
        val eosToken = 50257L

        while (tokenIds.size < maxTokens) {
            val inputIds =
                LongArray(tokenIds.size) { tokenIds[it] }

            val encoderTensor =
                OnnxTensor.createTensor(
                    ortEnvironment,
                    encoderHidden,
                )

            val inputTensor =
                OnnxTensor.createTensor(
                    ortEnvironment,
                    arrayOf(inputIds),
                )

            try {
                val inputs = mutableMapOf<String, OnnxTensor>()

                inputs["input_ids"] = inputTensor
                inputs["encoder_hidden_states"] = encoderTensor

                // Merged decoder is explicitly forced into no-cache mode.
                inputs["use_cache_branch"] =
                    OnnxTensor.createTensor(
                        ortEnvironment,
                        booleanArrayOf(false),
                    )

                inputs["cache_position"] =
                    OnnxTensor.createTensor(
                        ortEnvironment,
                        LongArray(inputIds.size) { it.toLong() },
                    )

                // Empty decoder KV cache.
                // Encoder KV inputs are supplied as empty placeholders
                // because use_cache_branch=false makes the graph use
                // encoder_hidden_states directly.
                for (layer in 0 until 6) {
                    inputs[
                        "past_key_values.$layer.decoder.key"
                    ] = emptyKvTensor()

                    inputs[
                        "past_key_values.$layer.decoder.value"
                    ] = emptyKvTensor()

                    inputs[
                        "past_key_values.$layer.encoder.key"
                    ] = emptyEncoderKvTensor()

                    inputs[
                        "past_key_values.$layer.encoder.value"
                    ] = emptyEncoderKvTensor()
                }

                try {
                    decoderSession.run(inputs).use { result ->
                        val logitsValue = result[0].value

                        val logits =
                            when (logitsValue) {
                                is Array<*> -> {
                                    @Suppress("UNCHECKED_CAST")
                                    logitsValue as Array<Array<FloatArray>>
                                }

                                else -> {
                                    throw IllegalStateException(
                                        "Unexpected decoder logits type: " +
                                            "${logitsValue?.javaClass?.name}",
                                    )
                                }
                            }

                        if (logits.size != 1) {
                            throw IllegalStateException(
                                "Unexpected decoder batch size: " +
                                    logits.size,
                            )
                        }

                        val sequenceLogits = logits[0]

                        if (sequenceLogits.isEmpty()) {
                            throw IllegalStateException(
                                "Decoder returned empty logits",
                            )
                        }

                        val lastLogits =
                            sequenceLogits[sequenceLogits.size - 1]
                        // Whisper-style rules: no blank/EOT as the very first
                        // token (unless the model hears no speech), and never
                        // emit special or timestamp tokens.
                        if (tokenIds.size == 4) {
                            var mx = Float.NEGATIVE_INFINITY
                            for (v in lastLogits) {
                                if (v > mx) mx = v
                            }
                            var sum = 0.0
                            for (v in lastLogits) {
                                sum += Math.exp((v - mx).toDouble())
                            }
                            val pNoSpeech =
                                Math.exp((lastLogits[50362] - mx).toDouble()) / sum
                            if (pNoSpeech > 0.8) return ""
                            lastLogits[220] = Float.NEGATIVE_INFINITY
                            lastLogits[50257] = Float.NEGATIVE_INFINITY
                        }
                        for (i in 50258 until lastLogits.size) {
                            lastLogits[i] = Float.NEGATIVE_INFINITY
                        }

                        var bestId = 0
                        var bestValue =
                            Float.NEGATIVE_INFINITY

                        for (i in lastLogits.indices) {
                            val value = lastLogits[i]

                            if (value > bestValue) {
                                bestValue = value
                                bestId = i
                            }
                        }

                        val nextToken = bestId.toLong()

                        if (nextToken == eosToken) {
                            return decodeTokens(tokenIds)
                        }

                        tokenIds.add(nextToken)
                        if (tokenIds.size >= 12) {
                            val tail = tokenIds.subList(tokenIds.size - 8, tokenIds.size)
                            if (tail.toSet().size <= 2) {
                                return decodeTokens(tokenIds.subList(0, tokenIds.size - 6))
                            }
                        }
                    }
                } finally {
                    inputs.values.forEach { tensor ->
                        try {
                            tensor.close()
                        } catch (_: Throwable) {
                        }
                    }
                }
            } finally {
                try {
                    inputTensor.close()
                } catch (_: Throwable) {
                }

                try {
                    encoderTensor.close()
                } catch (_: Throwable) {
                }
            }
        }

        return decodeTokens(tokenIds)
    }

    private fun emptyKvTensor(): OnnxTensor = placeholderKvTensor()

    private fun emptyEncoderKvTensor(): OnnxTensor = placeholderKvTensor()

    /**
     * Placeholder past_key_values for the merged decoder (use_cache_branch=false).
     * ORT Java rejects zero-length dimensions in nested arrays, so build the
     * tensor from a buffer. Fallback: length-1 dummy (unused by the no-cache branch).
     */
    private fun placeholderKvTensor(): OnnxTensor {
        return try {
            OnnxTensor.createTensor(
                ortEnvironment,
                java.nio.FloatBuffer.allocate(0),
                longArrayOf(1, 8, 0, 64),
            )
        } catch (_: Throwable) {
            OnnxTensor.createTensor(
                ortEnvironment,
                java.nio.FloatBuffer.allocate(8 * 64),
                longArrayOf(1, 8, 1, 64),
            )
        }
    }

    private fun decodeTokens(
        tokenIds: List<Long>,
    ): String {
        val vocab = loadVocab()

        val byteDecoder = buildByteDecoder()

        val bytes = ArrayList<Byte>()

        for (id in tokenIds) {
            if (id >= 50300L) continue

            val token =
                vocab.entries.firstOrNull {
                    it.value == id.toInt()
                }?.key
                    ?: continue

            for (ch in token) {
                val mapped = byteDecoder[ch]

                if (mapped != null) {
                    bytes.add(mapped.toByte())
                }
            }
        }

        return bytes.toByteArray()
            .toString(Charsets.UTF_8)
            .trim()
    }

    private var cachedVocab:
        Map<String, Int>? = null

    private fun loadVocab(): Map<String, Int> {
        cachedVocab?.let { return it }

        val text =
            context.assets.open(
                "vekol_stt/vocab.json",
            ).bufferedReader(Charsets.UTF_8).use {
                it.readText()
            }

        val json =
            org.json.JSONObject(text)

        val map = HashMap<String, Int>(
            json.length(),
        )

        val keys = json.keys()

        while (keys.hasNext()) {
            val key = keys.next()
            map[key] = json.getInt(key)
        }

        cachedVocab = map
        return map
    }

    private fun buildByteDecoder(): Map<Char, Int> {
        val bs = mutableListOf<Int>()

        for (i in '!'.code..'~'.code) {
            bs.add(i)
        }

        for (i in '¡'.code..'¬'.code) {
            bs.add(i)
        }

        for (i in '®'.code..'ÿ'.code) {
            bs.add(i)
        }

        val cs = bs.toMutableList()
        var n = 0

        for (b in 0..255) {
            if (!bs.contains(b)) {
                bs.add(b)
                cs.add(256 + n)
                n++
            }
        }

        val decoder = HashMap<Char, Int>(256)

        for (i in bs.indices) {
            decoder[cs[i].toChar()] = bs[i]
        }

        return decoder
    }

    fun dispose() {
        if (closed) return

        closed = true
        executor.shutdownNow()

        try {
            encoderSession.close()
        } catch (_: Throwable) {
        }

        try {
            decoderSession.close()
        } catch (_: Throwable) {
        }
    }
}
