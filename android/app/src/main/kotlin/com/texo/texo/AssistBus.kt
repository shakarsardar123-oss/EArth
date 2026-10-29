package com.texo.texo

import android.app.Activity
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Link between the assistant gesture (TexoAssistActivity + the screen flash)
 * and the Flutter side. The flash decides WHEN the conversation starts: only
 * after it has faded, [fire] tells Dart to begin.
 */
object AssistBus {
    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private val main = Handler(Looper.getMainLooper())

    @Volatile private var ready = false
    @Volatile private var cold = false
    @Volatile private var overlayOk = false

    /** True while a Flutter engine (MainActivity) is alive. */
    val alive: Boolean get() = channel != null

    fun attach(messenger: BinaryMessenger, act: Activity) {
        activity = act
        val ch = MethodChannel(messenger, "com.texo.texo/assist")
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "consume" -> {
                    val out = mapOf("ready" to ready, "cold" to cold, "overlay" to overlayOk)
                    if (ready) ready = false
                    result.success(out)
                }
                "moveToBack" -> {
                    try {
                        activity?.moveTaskToBack(true)
                    } catch (_: Throwable) {
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        channel = ch
    }

    fun detach(act: Activity) {
        if (activity === act) {
            channel?.setMethodCallHandler(null)
            channel = null
            activity = null
        }
    }

    fun begin(isCold: Boolean, canOverlay: Boolean) {
        ready = false
        cold = isCold
        overlayOk = canOverlay
    }

    /** The flash is over: Dart may start the conversation now. */
    fun fire() {
        ready = true
        val ch = channel ?: return
        main.post {
            try {
                ch.invokeMethod("assist", null)
            } catch (_: Throwable) {
            }
        }
    }
}
