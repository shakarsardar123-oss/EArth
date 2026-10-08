package com.texo.texo

import android.content.Context
import ai.onnxruntime.OnnxTensor
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
        val encoderBytes =
            context.assets.open(ENCODER_PATH).use { it.readBytes() }

        val decoderBytes =
            context.assets.open(DECODER_PATH).use { it.readBytes() }

        encoderSession = ortEnvironment.createSession(
            encoderBytes,
            OrtSession.SessionOptions(),
        )

        decoderSession = ortEnvironment.createSession(
            decoderBytes,
            OrtSession.SessionOptions(),
        )
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
                val text = transcribeBlocking(samples)
                onResult(text)
            } catch (t: Throwable) {
                onError(t)
            }
        }
    }

    private fun transcribeBlocking(samples: ShortArray): String {
        val features = whisperLogMel(samples)

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

            padded[lastStart + N_FFT + i] =
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

            fft(real, imag)

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

            val floor = maxLog - 8.0

            for (m in 0 until N_MELS) {
                val clipped = max(
                    mel[m],
                    floor,
                )

                output[m * N_FRAMES + frame] =
                    ((clipped + 4.0) / 4.0).toFloat()
            }
        }

        return output
    }

    private fun buildMelFilters(): Array<DoubleArray> {
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

    private fun decodeNoCache(
        encoderHidden: Array<Array<FloatArray>>,
    ): String {
        val tokenIds = mutableListOf(
            50258L, // <|startoftranscript|>
            50300L, // <|fa|>
            50359L, // <|transcribe|>
            50363L, // <|notimestamps|>
        )

        val maxTokens = 128
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

    private fun emptyKvTensor(): OnnxTensor {
        val data =
            Array(1) {
                Array(8) {
                    Array(0) {
                        FloatArray(64)
                    }
                }
            }

        return OnnxTensor.createTensor(
            ortEnvironment,
            data,
        )
    }

    private fun emptyEncoderKvTensor(): OnnxTensor {
        val data =
            Array(1) {
                Array(8) {
                    Array(0) {
                        FloatArray(64)
                    }
                }
            }

        return OnnxTensor.createTensor(
            ortEnvironment,
            data,
        )
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
