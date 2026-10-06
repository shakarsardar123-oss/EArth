package com.texo.texo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Surface
import io.flutter.plugin.common.EventChannel
import java.nio.ByteBuffer

class ScreenCaptureService : Service() {

    companion object {
        const val ACTION_START = "com.texo.texo.screen_capture.START"
        const val ACTION_STOP = "com.texo.texo.screen_capture.STOP"

        const val EXTRA_RESULT_CODE = "result_code"
        const val EXTRA_RESULT_DATA = "result_data"
        const val EXTRA_WIDTH = "width"
        const val EXTRA_HEIGHT = "height"
        const val EXTRA_DENSITY = "density"
        const val EXTRA_MAX_FPS = "max_fps"
        const val EXTRA_ROTATION = "rotation"
        const val EXTRA_PIXEL_FORMAT = "pixel_format"

        private const val NOTIFICATION_CHANNEL_ID = "texo_screen_capture"
        private const val NOTIFICATION_ID = 7301

        @Volatile
        private var ready = false

        @Volatile
        private var lastError: String? = null

        @Volatile
        private var eventSink: EventChannel.EventSink? = null

        private var latestFrame: Map<String, Any>? = null

        fun isReady(): Boolean = ready

        fun getLastError(): String? = lastError

        fun setEventSink(sink: EventChannel.EventSink?) {
            eventSink = sink
        }

        @Synchronized
        fun getLatestFrame(): Map<String, Any>? = latestFrame

        @Synchronized
        private fun setLatestFrame(frame: Map<String, Any>) {
            latestFrame = frame
        }

        fun clearState() {
            ready = false
            lastError = null
            synchronized(this) {
                latestFrame = null
            }
        }

        fun stop(context: android.content.Context) {
            context.stopService(
                Intent(context, ScreenCaptureService::class.java)
            )
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var imageSurface: Surface? = null

    private var width = 720
    private var height = 1280
    private var density = 160
    private var maxFps = 5
    private var rotation = 0
    private var outputPixelFormat = "rgba"

    private var lastFrameTimeMs = 0L

    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            cleanup(stopProjection = false)
            stopSelf()
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        if (intent?.action == ACTION_STOP) {
            cleanup(stopProjection = true)
            stopSelf()
            return START_NOT_STICKY
        }

        if (intent?.action != ACTION_START) {
            return START_NOT_STICKY
        }

        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, -1)

        @Suppress("DEPRECATION")
        val resultData =
            intent.getParcelableExtra<Intent>(EXTRA_RESULT_DATA)

        width = intent.getIntExtra(EXTRA_WIDTH, 720).coerceAtLeast(1)
        height = intent.getIntExtra(EXTRA_HEIGHT, 1280).coerceAtLeast(1)
        density = intent.getIntExtra(EXTRA_DENSITY, 160).coerceAtLeast(1)
        maxFps = intent.getIntExtra(EXTRA_MAX_FPS, 5).coerceAtLeast(1)
        rotation = intent.getIntExtra(EXTRA_ROTATION, 0)

        outputPixelFormat =
            intent.getStringExtra(EXTRA_PIXEL_FORMAT) ?: "rgba"

        ready = false
        lastError = null

        if (resultCode < 0 || resultData == null) {
            fail("Missing MediaProjection consent data")
            stopSelf()
            return START_NOT_STICKY
        }

        if (outputPixelFormat !in setOf("rgba", "bgra", "rgb565")) {
            fail("Unsupported pixel format: $outputPixelFormat")
            stopSelf()
            return START_NOT_STICKY
        }

        try {
            startAsForeground()
            startProjection(resultCode, resultData)
        } catch (t: Throwable) {
            fail("${t::class.java.simpleName}: ${t.message}")
            cleanup(stopProjection = true)
            stopSelf()
        }

        return START_NOT_STICKY
    }

    private fun startAsForeground() {
        val notification = buildNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
            )
        } else {
            @Suppress("DEPRECATION")
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun startProjection(
        resultCode: Int,
        resultData: Intent,
    ) {
        val manager =
            getSystemService(MediaProjectionManager::class.java)
                ?: throw IllegalStateException(
                    "MediaProjectionManager unavailable"
                )

        mediaProjection =
            manager.getMediaProjection(resultCode, resultData)
                ?: throw IllegalStateException(
                    "getMediaProjection returned null"
                )

        mediaProjection?.registerCallback(
            projectionCallback,
            mainHandler,
        )

        imageReader = ImageReader.newInstance(
            width,
            height,
            PixelFormat.RGBA_8888,
            2,
        )

        imageReader?.setOnImageAvailableListener(
            { reader ->
                handleImage(reader)
            },
            mainHandler,
        )

        imageSurface =
            imageReader?.surface
                ?: throw IllegalStateException(
                    "ImageReader surface unavailable"
                )

        virtualDisplay =
            mediaProjection?.createVirtualDisplay(
                "TEXO Screen Capture",
                width,
                height,
                density,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                imageSurface,
                null,
                mainHandler,
            )

        if (virtualDisplay == null) {
            throw IllegalStateException(
                "createVirtualDisplay returned null"
            )
        }

        ready = true
        lastError = null
    }

    private fun handleImage(reader: ImageReader) {
        val now = System.currentTimeMillis()
        val minInterval = (1000L / maxFps.coerceAtLeast(1))

        if (now - lastFrameTimeMs < minInterval) {
            reader.acquireLatestImage()?.close()
            return
        }

        val image = try {
            reader.acquireLatestImage()
        } catch (_: Throwable) {
            null
        } ?: return

        try {
            val frame = imageToFrame(image)
            lastFrameTimeMs = now

            setLatestFrame(frame)
            eventSink?.success(frame)
        } catch (t: Throwable) {
            lastError =
                "Frame conversion failed: ${t::class.java.simpleName}: ${t.message}"
        } finally {
            image.close()
        }
    }

    private fun imageToFrame(image: Image): Map<String, Any> {
        val imageWidth = image.width
        val imageHeight = image.height

        val planes = image.planes
        if (planes.isEmpty()) {
            throw IllegalStateException("Image has no planes")
        }

        val plane = planes[0]
        val buffer = plane.buffer
        val pixelStride = plane.pixelStride
        val rowStride = plane.rowStride
        val basePosition = buffer.position()

        val rgba =
            ByteArray(imageWidth * imageHeight * 4)

        var dst = 0

        for (y in 0 until imageHeight) {
            val rowStart =
                basePosition + y * rowStride

            for (x in 0 until imageWidth) {
                val source =
                    rowStart + x * pixelStride

                rgba[dst++] = buffer.get(source)
                rgba[dst++] = buffer.get(source + 1)
                rgba[dst++] = buffer.get(source + 2)
                rgba[dst++] = buffer.get(source + 3)
            }
        }

        val output = when (outputPixelFormat) {
            "bgra" -> rgbaToBgra(rgba)
            "rgb565" -> rgbaToRgb565(rgba)
            else -> rgba
        }

        return mapOf(
            "bytes" to output,
            "width" to imageWidth,
            "height" to imageHeight,
            "timestamp" to System.currentTimeMillis(),
            "rotation" to rotation,
            "pixelFormat" to outputPixelFormat,
        )
    }

    private fun rgbaToBgra(input: ByteArray): ByteArray {
        val output = input.copyOf()

        var i = 0
        while (i + 3 < output.size) {
            val r = output[i]
            output[i] = output[i + 2]
            output[i + 2] = r
            i += 4
        }

        return output
    }

    private fun rgbaToRgb565(input: ByteArray): ByteArray {
        val output = ByteArray((input.size / 4) * 2)

        var src = 0
        var dst = 0

        while (src + 3 < input.size) {
            val r = input[src].toInt() and 0xFF
            val g = input[src + 1].toInt() and 0xFF
            val b = input[src + 2].toInt() and 0xFF

            val value =
                ((r shr 3) shl 11) or
                ((g shr 2) shl 5) or
                (b shr 3)

            output[dst++] = (value and 0xFF).toByte()
            output[dst++] = ((value shr 8) and 0xFF).toByte()

            src += 4
        }

        return output
    }

    private fun fail(message: String) {
        ready = false
        lastError = message
    }

    private fun cleanup(stopProjection: Boolean) {
        ready = false

        try {
            mediaProjection?.unregisterCallback(projectionCallback)
        } catch (_: Throwable) {
        }

        if (stopProjection) {
            try {
                mediaProjection?.stop()
            } catch (_: Throwable) {
            }
        }

        try {
            virtualDisplay?.release()
        } catch (_: Throwable) {
        }

        try {
            imageReader?.setOnImageAvailableListener(null, null)
        } catch (_: Throwable) {
        }

        try {
            imageReader?.close()
        } catch (_: Throwable) {
        }

        imageSurface = null
        virtualDisplay = null
        imageReader = null
        mediaProjection = null
        lastFrameTimeMs = 0L

        synchronized(ScreenCaptureService::class.java) {
            latestFrame = null
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (_: Throwable) {
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager =
            getSystemService(NotificationManager::class.java)

        manager.createNotificationChannel(
            NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "TEXO Screen Capture",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description =
                    "Screen capture used by TEXO screen understanding"
            }
        )
    }

    private fun buildNotification(): Notification {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_menu_view)
                .setContentTitle("TEXO")
                .setContentText("Screen understanding is active")
                .setOngoing(true)
                .setCategory(Notification.CATEGORY_SERVICE)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setSmallIcon(android.R.drawable.ic_menu_view)
                .setContentTitle("TEXO")
                .setContentText("Screen understanding is active")
                .setOngoing(true)
                .setCategory(Notification.CATEGORY_SERVICE)
                .build()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        cleanup(stopProjection = true)
        super.onDestroy()
    }
}
