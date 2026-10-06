package com.texo.texo

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

object FloatingTexoBridge {
    private const val CHANNEL_NAME = "com.texo.texo/floating_texo_overlay"
    private const val SHOW_TIMEOUT_MS = 5000L
    private const val POLL_INTERVAL_MS = 100L

    private var service: FloatingTexoOverlayService? = null
    private var bound = false

    private val mainHandler = Handler(Looper.getMainLooper())

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(
            name: ComponentName,
            binder: IBinder,
        ) {
            service = (binder as FloatingTexoOverlayService.LocalBinder).service()
            bound = true
        }

        override fun onServiceDisconnected(name: ComponentName) {
            service = null
            bound = false
        }
    }

    fun attach(
        activity: MainActivity,
        flutterEngine: FlutterEngine,
    ) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            handle(activity, call, result)
        }
    }

    fun detach(activity: MainActivity) {
        mainHandler.removeCallbacksAndMessages(null)

        if (bound) {
            try {
                activity.unbindService(connection)
            } catch (_: Throwable) {
            }
            bound = false
        }

        service = null
    }

    private fun handle(
        activity: MainActivity,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "hasPermission" -> {
                result.success(
                    mapOf(
                        "granted" to canDrawOverlays(activity),
                    ),
                )
            }

            "requestPermission" -> {
                if (canDrawOverlays(activity)) {
                    result.success(mapOf("granted" to true))
                } else {
                    openOverlaySettingsIntent(activity)
                    result.success(mapOf("granted" to false))
                }
            }

            "openOverlaySettings" -> {
                openOverlaySettingsIntent(activity)
                result.success(null)
            }

            "showOverlay" -> {
                if (!canDrawOverlays(activity)) {
                    result.success(
                        mapOf(
                            "shown" to false,
                            "error" =>
                                "SYSTEM_ALERT_WINDOW permission not granted",
                        ),
                    )
                    return
                }

                val x = (call.argument<Number>("x") ?: 16).toInt()
                val y = (call.argument<Number>("y") ?: 100).toInt()

                startAndBind(activity, x, y)

                waitForOverlayReady(result)
            }

            "hideOverlay" -> {
                service?.hide()

                if (bound) {
                    try {
                        activity.unbindService(connection)
                    } catch (_: Throwable) {
                    }
                    bound = false
                }

                service = null
                result.success(null)
            }

            "updatePosition" -> {
                val x = (call.argument<Number>("x") ?: 0).toInt()
                val y = (call.argument<Number>("y") ?: 0).toInt()

                service?.updatePosition(x, y)
                result.success(null)
            }

            "togglePanel" -> {
                val expanded = service?.togglePanel() ?: false
                result.success(mapOf("isExpanded" to expanded))
            }

            "isOverlayVisible" -> {
                result.success(
                    mapOf(
                        "visible" to (service?.isOverlayShowing() ?: false),
                    ),
                )
            }

            else -> result.notImplemented()
        }
    }

    private fun waitForOverlayReady(
        result: MethodChannel.Result,
        startedAt: Long = System.currentTimeMillis(),
    ) {
        val currentService = service

        if (currentService != null) {
            if (currentService.isOverlayShowing()) {
                result.success(
                    mapOf(
                        "shown" to true,
                    ),
                )
                return
            }

            val error = currentService.overlayError()

            if (error != null) {
                result.success(
                    mapOf(
                        "shown" to false,
                        "error" to error,
                    ),
                )
                return
            }
        }

        if (System.currentTimeMillis() - startedAt >= SHOW_TIMEOUT_MS) {
            result.success(
                mapOf(
                    "shown" to false,
                    "error" =>
                        "Overlay service did not create a visible window within ${SHOW_TIMEOUT_MS}ms",
                ),
            )
            return
        }

        mainHandler.postDelayed(
            {
                waitForOverlayReady(result, startedAt)
            },
            POLL_INTERVAL_MS,
        )
    }

    private fun startAndBind(
        activity: MainActivity,
        xDp: Int,
        yDp: Int,
    ) {
        val intent =
            Intent(activity, FloatingTexoOverlayService::class.java).apply {
                putExtra(
                    FloatingTexoOverlayService.EXTRA_POS_X_DP,
                    xDp,
                )
                putExtra(
                    FloatingTexoOverlayService.EXTRA_POS_Y_DP,
                    yDp,
                )
            }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity.startForegroundService(intent)
        } else {
            activity.startService(intent)
        }

        if (!bound) {
            activity.bindService(
                intent,
                connection,
                Context.BIND_AUTO_CREATE,
            )
        }
    }

    private fun canDrawOverlays(activity: MainActivity): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(activity)
        } else {
            true
        }
    }

    private fun openOverlaySettingsIntent(activity: MainActivity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${activity.packageName}"),
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            activity.startActivity(intent)
        }
    }
}
