package com.texo.texo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.View
import android.widget.TextView
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.WindowManager
import kotlin.math.max
import kotlin.math.min

/**
 * Foreground service that owns the TEXO floating overlay (the pill drawn by
 * [TexoOverlayView]) and reports the REAL result of WindowManager.addView().
 */
class FloatingTexoOverlayService : Service() {

    inner class LocalBinder : Binder() {
        fun service(): FloatingTexoOverlayService = this@FloatingTexoOverlayService
    }

    private val binder = LocalBinder()

    private lateinit var windowManager: WindowManager

    private var overlayView: TexoOverlayView? = null
    private var translatedSubtitleView: TextView? = null
    private var layoutParams: WindowManager.LayoutParams? = null

    private var isShowing = false
    private var lastOverlayError: String? = null
    private var pendingState: Map<*, *>? = null
    private var wantVisible = true

    var onOverlayAction: ((String) -> Unit)? = null

    companion object {
        const val EXTRA_POS_X_DP = "posXDp"
        const val EXTRA_POS_Y_DP = "posYDp"
        const val EXTRA_HIDDEN = "hidden"

        private const val NOTIFICATION_CHANNEL_ID = "texo_floating_overlay_v3"
        private const val NOTIFICATION_ID = 4201
        private const val OVERLAY_WIDTH_DP = 290f
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val fgNotification = buildNotification()
        var fgOk = false
        var fgErr = ""
        try {
            startForeground(NOTIFICATION_ID, fgNotification)
            fgOk = true
        } catch (e: Throwable) {
            fgErr = "${e::class.java.simpleName}: ${e.message}"
            debugLog("TEXO: startForeground failed: $fgErr")
            if (Build.VERSION.SDK_INT >= 34) {
                try {
                    startForeground(
                        NOTIFICATION_ID,
                        fgNotification,
                        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
                    )
                    fgOk = true
                    debugLog("TEXO: fallback specialUse OK")
                } catch (e2: Throwable) {
                    fgErr = "${e2::class.java.simpleName}: ${e2.message}"
                    debugLog("TEXO: fallback FAILED: $fgErr")
                }
            }
        }
        if (!fgOk) {
            lastOverlayError = "startForeground failed: $fgErr"
            stopSelf()
            return START_NOT_STICKY
        }
        debugLog("TEXO: service started (foreground OK)")

        if (intent != null && intent.hasExtra(EXTRA_HIDDEN)) {
            wantVisible = !intent.getBooleanExtra(EXTRA_HIDDEN, false)
        }
        if (overlayView == null && wantVisible) {
            showOverlayInternal()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        debugLog("TEXO: service onDestroy")
        removeOverlayInternal()
        super.onDestroy()
    }

    private fun debugLog(msg: String) {
        TexoLog.log(applicationContext, msg)
    }

    // ---- API used by FloatingTexoBridge ------------------------------------------------

    fun isOverlayShowing(): Boolean = isShowing

    fun overlayError(): String? = lastOverlayError

    fun hide() {
        debugLog("TEXO: hide() called")
        removeOverlayInternal()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    /**
     * Show or hide the pill WITHOUT stopping the foreground service, so the
     * app can start Live Mode while visible and only reveal the pill when the
     * user leaves the app.
     */
    fun setVisible(visible: Boolean) {
        wantVisible = visible
        if (visible) {
            if (overlayView == null) showOverlayInternal()
        } else {
            removeOverlayInternal()
        }
    }

    /** The pill is pinned under the camera; kept for API compatibility. */
    fun updatePosition(xDp: Int, yDp: Int) {
    }

    /** Opens / closes the tools tray. */
    fun togglePanel(): Boolean = overlayView?.toggleTray() ?: false

    /** State pushed from Dart: mode, level, emoji, flags, subtitle texts. */
    fun applyState(state: Map<*, *>) {
        val merged = HashMap<Any?, Any?>()
        pendingState?.forEach { (key, value) -> merged[key] = value }
        state.forEach { (key, value) -> merged[key] = value }
        pendingState = merged
        overlayView?.applyState(merged)
        updateTranslatedSubtitle(merged)
    }

    // ---- window ------------------------------------------------------------------------------

    @Suppress("DEPRECATION")
    private fun overlayType(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }

    private fun statusBarHeightPx(): Int {
        val id = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (id > 0) resources.getDimensionPixelSize(id) else (24f * resources.displayMetrics.density).toInt()
    }

    private fun showOverlayInternal() {
        lastOverlayError = null
        isShowing = false

        val view = TexoOverlayView(this)
        view.listener = object : TexoOverlayView.Listener {
            override fun onAction(action: String) {
                onOverlayAction?.invoke(action)
            }
        }
        overlayView = view

        val metrics = resources.displayMetrics
        val widthPx = min(
            (OVERLAY_WIDTH_DP * metrics.density).toInt(),
            metrics.widthPixels - (16f * metrics.density).toInt(),
        )
        val topPx = max(statusBarHeightPx() - (4f * metrics.density).toInt(), (18f * metrics.density).toInt())

        val params = WindowManager.LayoutParams(
            widthPx,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            x = 0
            y = topPx
        }
        layoutParams = params

        try {
            windowManager.addView(view, params)
            isShowing = true
            lastOverlayError = null
            pendingState?.let {
                view.applyState(it)
                updateTranslatedSubtitle(it)
            }
            debugLog("TEXO: overlay view added OK")
        } catch (error: Throwable) {
            isShowing = false
            lastOverlayError = buildString {
                append("WindowManager.addView failed")
                val message = error.message
                if (!message.isNullOrBlank()) {
                    append(": ")
                    append(message)
                }
                append(" [")
                append(error::class.java.simpleName)
                append("]")
            }
            debugLog("TEXO: addView FAILED: $lastOverlayError")
            overlayView = null
            layoutParams = null
        }
    }

    private fun removeOverlayInternal() {
        removeTranslatedSubtitleInternal()

        val view = overlayView
        if (view != null) {
            try {
                windowManager.removeView(view)
            } catch (_: Throwable) {
            }
        }

        overlayView = null
        layoutParams = null
        isShowing = false
        lastOverlayError = null
    }

    private fun updateTranslatedSubtitle(state: Map<*, *>?) {
        val enabled = state?.get("trans") as? Boolean ?: false
        val subtitleText = (state?.get("translatedSubtitle") as? String)
            ?.trim().orEmpty()

        if (!wantVisible || !isShowing || !enabled || subtitleText.isBlank()) {
            removeTranslatedSubtitleInternal()
            return
        }

        val existing = translatedSubtitleView
        if (existing != null) {
            if (existing.text.toString() != subtitleText) existing.text = subtitleText
            return
        }

        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()

        val subtitle = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 18f
            gravity = Gravity.CENTER
            textAlignment = View.TEXT_ALIGNMENT_CENTER
            textDirection = View.TEXT_DIRECTION_RTL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            maxLines = 3
            setPadding(dp(16), dp(10), dp(16), dp(10))
            background = GradientDrawable().apply {
                setColor(Color.argb(232, 12, 16, 28))
                cornerRadius = dp(14).toFloat()
                setStroke(
                    dp(1).coerceAtLeast(1),
                    Color.argb(170, 70, 200, 255)
                )
            }
            text = subtitleText
        }

        val params = WindowManager.LayoutParams(
            (resources.displayMetrics.widthPixels - dp(32)).coerceAtLeast(dp(200)),
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            x = 0
            y = dp(76)
        }

        try {
            windowManager.addView(subtitle, params)
            translatedSubtitleView = subtitle
            debugLog("TEXO: translated subtitle added")
        } catch (error: Throwable) {
            translatedSubtitleView = null
            debugLog("TEXO: translated subtitle failed: ${error.message}")
        }
    }

    private fun removeTranslatedSubtitleInternal() {
        val subtitle = translatedSubtitleView ?: return
        try {
            windowManager.removeView(subtitle)
        } catch (_: Throwable) {
        }
        translatedSubtitleView = null
    }

    // ---- notification ----------------------------------------------------------------------

    @Suppress("DEPRECATION")
    private fun legacyBuilder(): Notification.Builder = Notification.Builder(this)

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "TEXO Live",
                NotificationManager.IMPORTANCE_LOW,
            )
            nm.createNotificationChannel(channel)
        }
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pending = if (launch != null) {
            PendingIntent.getActivity(
                this,
                0,
                launch,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        } else {
            null
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            legacyBuilder()
        }
        builder
            .setContentTitle("TEXO")
            .setContentText("Live")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
        if (pending != null) builder.setContentIntent(pending)
        return builder.build()
    }
}
