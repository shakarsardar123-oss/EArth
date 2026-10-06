package com.texo.texo

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger

class ScreenCaptureBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    companion object {
        private const val METHOD_CHANNEL =
            "com.texo.texo/screen_capture"

        private const val EVENT_CHANNEL =
            "com.texo.texo/screen_capture_frames"

        private const val REQUEST_PROJECTION = 7302

        private const val START_TIMEOUT_MS = 5000L
        private const val POLL_MS = 100L
    }

    private val methodChannel =
        MethodChannel(messenger, METHOD_CHANNEL)

    private val eventChannel =
        EventChannel(messenger, EVENT_CHANNEL)

    private val handler =
        Handler(Looper.getMainLooper())

    private var pendingProjectionResult:
        MethodChannel.Result? = null

    private var disposed = false

    init {
        methodChannel.setMethodCallHandler(::handleMethodCall)

        eventChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?,
                ) {
                    ScreenCaptureService.setEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    ScreenCaptureService.setEventSink(null)
                }
            }
        )
    }

    private fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "requestProjection" -> {
                requestProjection(result)
            }

            "startCapture" -> {
                startCapture(call, result)
            }

            "stopCapture" -> {
                ScreenCaptureService.stop(activity)
                ScreenCaptureService.clearState()
                result.success(null)
            }

            "captureSingleFrame" -> {
                val frame =
                    ScreenCaptureService.getLatestFrame()

                if (frame == null) {
                    result.error(
                        "NO_FRAME",
                        "No captured frame is available yet",
                        null,
                    )
                } else {
                    result.success(frame)
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun requestProjection(
        result: MethodChannel.Result,
    ) {
        if (disposed) {
            result.error(
                "DISPOSED",
                "Screen capture bridge is disposed",
                null,
            )
            return
        }

        if (pendingProjectionResult != null) {
            result.error(
                "REQUEST_IN_PROGRESS",
                "A screen capture permission request is already active",
                null,
            )
            return
        }

        try {
            ScreenCaptureService.stop(activity)
            ScreenCaptureService.clearState()

            val manager =
                activity.getSystemService(
                    android.media.projection.MediaProjectionManager::class.java
                ) ?: run {
                    result.error(
                        "UNAVAILABLE",
                        "MediaProjectionManager unavailable",
                        null,
                    )
                    return
                }

            pendingProjectionResult = result

            activity.startActivityForResult(
                manager.createScreenCaptureIntent(),
                REQUEST_PROJECTION,
            )
        } catch (t: Throwable) {
            pendingProjectionResult = null

            result.error(
                "PROJECTION_REQUEST_FAILED",
                "${t::class.java.simpleName}: ${t.message}",
                null,
            )
        }
    }

    private fun startCapture(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        if (disposed) {
            result.error(
                "DISPOSED",
                "Screen capture bridge is disposed",
                null,
            )
            return
        }

        if (!ScreenCaptureBridgeState.hasProjectionConsent) {
            result.success(
                mapOf(
                    "started" to false,
                    "error" to "MediaProjection permission has not been granted",
                )
            )
            return
        }

        val data =
            ScreenCaptureBridgeState.resultData ?: run {
                result.success(
                    mapOf(
                        "started" to false,
                        "error" to "Missing MediaProjection result data",
                    )
                )
                return
            }

        val resultCode =
            ScreenCaptureBridgeState.resultCode

        val width =
            call.argument<Int>("width") ?: 720
        val height =
            call.argument<Int>("height") ?: 1280
        val density =
            call.argument<Int>("density") ?: 160
        val maxFps =
            call.argument<Int>("maxFramesPerSecond") ?: 5
        val rotation =
            call.argument<Int>("rotation") ?: 0
        val pixelFormat =
            call.argument<String>("pixelFormat") ?: "rgba"

        ScreenCaptureService.clearState()

        try {
            val intent =
                Intent(
                    activity,
                    ScreenCaptureService::class.java,
                ).apply {
                    action = ScreenCaptureService.ACTION_START

                    putExtra(
                        ScreenCaptureService.EXTRA_RESULT_CODE,
                        resultCode,
                    )
                    putExtra(
                        ScreenCaptureService.EXTRA_RESULT_DATA,
                        data,
                    )
                    putExtra(
                        ScreenCaptureService.EXTRA_WIDTH,
                        width,
                    )
                    putExtra(
                        ScreenCaptureService.EXTRA_HEIGHT,
                        height,
                    )
                    putExtra(
                        ScreenCaptureService.EXTRA_DENSITY,
                        density,
                    )
                    putExtra(
                        ScreenCaptureService.EXTRA_MAX_FPS,
                        maxFps,
                    )
                    putExtra(
                        ScreenCaptureService.EXTRA_ROTATION,
                        rotation,
                    )
                    putExtra(
                        ScreenCaptureService.EXTRA_PIXEL_FORMAT,
                        pixelFormat,
                    )
                }

            if (android.os.Build.VERSION.SDK_INT >=
                android.os.Build.VERSION_CODES.O
            ) {
                activity.startForegroundService(intent)
            } else {
                activity.startService(intent)
            }

            waitForService(result, width, height, density)
        } catch (t: Throwable) {
            result.success(
                mapOf(
                    "started" to false,
                    "error" to
                        "${t::class.java.simpleName}: ${t.message}",
                )
            )
        }
    }

    private fun waitForService(
        result: MethodChannel.Result,
        width: Int,
        height: Int,
        density: Int,
    ) {
        val deadline =
            android.os.SystemClock.uptimeMillis() +
                START_TIMEOUT_MS

        fun poll() {
            if (disposed) return

            if (ScreenCaptureService.isReady()) {
                result.success(
                    mapOf(
                        "started" to true,
                        "width" to width,
                        "height" to height,
                        "density" to density,
                    )
                )
                return
            }

            val error =
                ScreenCaptureService.getLastError()

            if (!error.isNullOrBlank()) {
                result.success(
                    mapOf(
                        "started" to false,
                        "error" to error,
                    )
                )
                return
            }

            if (android.os.SystemClock.uptimeMillis() >=
                deadline
            ) {
                ScreenCaptureService.stop(activity)

                result.success(
                    mapOf(
                        "started" to false,
                        "error" to
                            "Timed out waiting for MediaProjection service",
                    )
                )
                return
            }

            handler.postDelayed(
                { poll() },
                POLL_MS,
            )
        }

        poll()
    }

    fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ): Boolean {
        if (requestCode != REQUEST_PROJECTION) {
            return false
        }

        val result =
            pendingProjectionResult

        pendingProjectionResult = null

        if (resultCode != Activity.RESULT_OK || data == null) {
            ScreenCaptureBridgeState.clear()

            result?.success(
                mapOf(
                    "granted" to false,
                )
            )

            return true
        }

        ScreenCaptureBridgeState.resultCode =
            resultCode
        ScreenCaptureBridgeState.resultData =
            data
        ScreenCaptureBridgeState.hasProjectionConsent =
            true

        result?.success(
            mapOf(
                "granted" to true,
            )
        )

        return true
    }

    fun dispose() {
        if (disposed) return

        disposed = true

        pendingProjectionResult?.error(
            "DISPOSED",
            "Screen capture bridge disposed",
            null,
        )
        pendingProjectionResult = null

        ScreenCaptureService.setEventSink(null)

        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)

        handler.removeCallbacksAndMessages(null)

        ScreenCaptureService.stop(activity)
        ScreenCaptureBridgeState.clear()
    }
}

private object ScreenCaptureBridgeState {
    var resultCode: Int = -1
    var resultData: Intent? = null
    var hasProjectionConsent: Boolean = false

    fun clear() {
        resultCode = -1
        resultData = null
        hasProjectionConsent = false
    }
}
