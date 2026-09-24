package com.texo.texo

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Owns the platform-channel wiring for the floating-overlay subsystem
 * (channel name: com.texo.texo/floating_texo_overlay — must
 * match FloatingAuraMethodNames / floatingAuraMethodChannelName on the
 * Dart side), independent of [MainActivity]'s existing channel handlers.
 *
 * Kept in its own file/singleton so this feature can be wired up
 * without editing the body of the existing (already large)
 * [MainActivity]. MainActivity only needs to call [attach] once from
 * configureFlutterEngine() and [detach] once from onDestroy().
 */
object FloatingTexoBridge {

    private const val CHANNEL_NAME = "com.texo.texo/floating_texo_overlay"

    private var service: FloatingTexoOverlayService? = null
    private var bound = false

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            service = (binder as FloatingTexoOverlayService.LocalBinder).service()
            bound = true
        }

        override fun onServiceDisconnected(name: ComponentName) {
            service = null
            bound = false
        }
    }

    /** Call once from MainActivity.configureFlutterEngine(). */
    fun attach(activity: MainActivity, flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result -> handle(activity, call, result) }
    }

    /** Call once from MainActivity.onDestroy(). */
    fun detach(activity: MainActivity) {
        if (bound) {
            try {
                activity.unbindService(connection)
            } catch (_: Throwable) {
                // Not bound / already unbound — safe to ignore.
            }
            bound = false
        }
        service = null
    }

    private fun handle(activity: MainActivity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> {
                result.success(mapOf("granted" to canDrawOverlays(activity)))
            }

            "requestPermission" -> {
                if (canDrawOverlays(activity)) {
                    result.success(mapOf("granted" to true))
                } else {
                    openOverlaySettingsIntent(activity)
                    // ACTION_MANAGE_OVERLAY_PERMISSION does not reliably return
                    // an activity result across OEMs/versions. The Dart side
                    // (FloatingAuraStateNotifier.checkPermission) is expected
                    // to call hasPermission() again when the app resumes.
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
                            "error" to "SYSTEM_ALERT_WINDOW permission not granted"
                        )
                    )
                    return
                }
                val x = (call.argument<Number>("x") ?: 16).toInt()
                val y = (call.argument<Number>("y") ?: 100).toInt()
                startAndBind(activity, x, y)
                result.success(mapOf("shown" to true))
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
                result.success(mapOf("visible" to (service?.isOverlayShowing() ?: false)))
            }

            else -> result.notImplemented()
        }
    }

    private fun startAndBind(activity: MainActivity, xDp: Int, yDp: Int) {
        val intent = Intent(activity, FloatingTexoOverlayService::class.java).apply {
            putExtra(FloatingTexoOverlayService.EXTRA_POS_X_DP, xDp)
            putExtra(FloatingTexoOverlayService.EXTRA_POS_Y_DP, yDp)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity.startForegroundService(intent)
        } else {
            activity.startService(intent)
        }
        if (!bound) {
            activity.bindService(intent, connection, Context.BIND_AUTO_CREATE)
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
                Uri.parse("package:${activity.packageName}")
            ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
            activity.startActivity(intent)
        }
    }
}
