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
        val modelBytes = context.assets.open(MODEL_PATH).use { it.readBytes() }

        session = ortEnvironment.createSession(
            modelBytes,
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
                onComplete(t)
            }
        }
    }

    private fun speakBlocking(text: String) {
        val ids = buildIds(text)

        val input = OnnxTensor.createTensor(
            ortEnvironment,
            LongBuffer.wrap(ids),
            longArrayOf(1, ids.size.toLong())
        )

        val inputLengths = OnnxTensor.createTensor(
            ortEnvironment,
            LongBuffer.wrap(longArrayOf(ids.size.toLong())),
            longArrayOf(1)
        )

        val scales = OnnxTensor.createTensor(
            ortEnvironment,
            FloatBuffer.wrap(floatArrayOf(0.667f, 1.0f, 0.35f)),
            longArrayOf(3)
        )

        val sid = OnnxTensor.createTensor(
            ortEnvironment,
            LongBuffer.wrap(longArrayOf(0L)),
            longArrayOf(1)
        )

        try {
            session.run(
                mapOf(
                    "input" to input,
                    "input_lengths" to inputLengths,
                    "scales" to scales,
                    "sid" to sid
                )
            ).use { result ->

                if (stopped) return

                val output = result[0].value
                val audio = extractAudio(output)

                if (audio.isNotEmpty()) {
                    play(audio)
                }
            }
        } finally {
            input.close()
            inputLengths.close()
            scales.close()
            sid.close()
        }
    }

    private fun buildIds(text: String): LongArray {
        val normalized = normalize(text)

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

    private fun play(samples: FloatArray) {
        val minBuffer = AudioTrack.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        val bufferSize = max(minBuffer, samples.size * 2)

        val track = AudioTrack.Builder()
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

        synchronized(this) {
            audioTrack = track
        }

        try {
            track.play()

            val pcm = ShortArray(samples.size)

            for (i in samples.indices) {
                val v = samples[i].coerceIn(-1f, 1f)
                pcm[i] = (v * 32767f).roundToInt().toShort()
            }

            var offset = 0

            while (offset < pcm.size && !stopped) {
                val written = track.write(
                    pcm,
                    offset,
                    pcm.size - offset
                )

                if (written <= 0) break

                offset += written
            }

            if (!stopped) {
                while (track.playbackHeadPosition.toLong() < pcm.size.toLong()) {
                    Thread.sleep(10)
                }
            }
        } finally {
            try {
                track.stop()
            } catch (_: Throwable) {
            }

            try {
                track.release()
            } catch (_: Throwable) {
            }

            synchronized(this) {
                if (audioTrack === track) {
                    audioTrack = null
                }
            }
        }
    }

    fun dispose() {
        stop()
        executor.shutdownNow()
        session.close()
    }
}
