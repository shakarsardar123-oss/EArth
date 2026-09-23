package com.aura.aura_assistant

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView

/**
 * Foreground service that owns the AURA floating overlay's native
 * WindowManager view.
 *
 * Phase 6-B scope (matches [AuraOverlayHostWidget] on the Dart side):
 * draws a simple NATIVE collapsed button / expanded panel — tap to
 * toggle, drag to move. It does NOT host a Flutter [FlutterView] yet;
 * that is Phase 6-C+ work per the existing Dart-side documentation.
 * This gives every method [FloatingAuraService] declares (show/hide/
 * move/toggle/visibility) a real, working native implementation.
 *
 * Bound + started hybrid:
 *  - Started (startForegroundService) so the overlay survives the host
 *    Activity being backgrounded/destroyed.
 *  - Bound by [FloatingAuraBridge] so position/toggle/visibility calls
 *    can be answered synchronously while the app process is alive.
 */
class FloatingAuraOverlayService : Service() {

    inner class LocalBinder : Binder() {
        fun service(): FloatingAuraOverlayService = this@FloatingAuraOverlayService
    }

    private val binder = LocalBinder()

    private lateinit var windowManager: WindowManager
    private var overlayView: FrameLayout? = null
    private var layoutParams: WindowManager.LayoutParams? = null

    private var isExpanded = false
    private var isShowing = false

    private var posX = 0
    private var posY = 0

    companion object {
        const val EXTRA_POS_X_DP = "posXDp"
        const val EXTRA_POS_Y_DP = "posYDp"

        private const val NOTIFICATION_CHANNEL_ID = "aura_floating_overlay"
        private const val NOTIFICATION_ID = 4201

        private const val COLLAPSED_SIZE_DP = 56
        private const val EXPANDED_WIDTH_DP = 280
        private const val EXPANDED_HEIGHT_DP = 400
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())

        if (overlayView == null) {
            val xDp = intent?.getIntExtra(EXTRA_POS_X_DP, 16) ?: 16
            val yDp = intent?.getIntExtra(EXTRA_POS_Y_DP, 100) ?: 100
            showOverlayInternal(xDp, yDp)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        removeOverlayInternal()
        super.onDestroy()
    }

    // ─── Public API used by FloatingAuraBridge via LocalBinder ────────

    fun isOverlayShowing(): Boolean = isShowing

    fun hide() {
        removeOverlayInternal()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    fun updatePosition(xDp: Int, yDp: Int) {
        val view = overlayView ?: return
        val params = layoutParams ?: return
        posX = dpToPx(xDp)
        posY = dpToPx(yDp)
        params.x = posX
        params.y = posY
        try {
            windowManager.updateViewLayout(view, params)
        } catch (_: Throwable) {
            // View may already be detached; ignore.
        }
    }

    fun togglePanel(): Boolean {
        isExpanded = !isExpanded
        applyExpandedState()
        return isExpanded
    }

    // ─── Overlay view construction ─────────────────────────────────────

    private fun showOverlayInternal(xDp: Int, yDp: Int) {
        posX = dpToPx(xDp)
        posY = dpToPx(yDp)

        val view = buildOverlayView()
        overlayView = view

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            dpToPx(COLLAPSED_SIZE_DP),
            dpToPx(COLLAPSED_SIZE_DP),
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = posX
            y = posY
        }
        layoutParams = params

        attachDragHandling(view, params)

        try {
            windowManager.addView(view, params)
            isShowing = true
        } catch (_: Throwable) {
            isShowing = false
        }
    }

    private fun removeOverlayInternal() {
        val view = overlayView ?: return
        try {
            windowManager.removeView(view)
        } catch (_: Throwable) {
            // Already removed.
        }
        overlayView = null
        layoutParams = null
        isShowing = false
        isExpanded = false
    }

    /**
     * Native collapsed-button / expanded-panel view. Mirrors
     * [AuraOverlayHostWidget]'s Phase 6-B placeholder content (cyan
     * accent on a dark surface) until a hosted [FlutterView] replaces
     * it in a later phase.
     */
    private fun buildOverlayView(): FrameLayout {
        val container = FrameLayout(this)

        val label = TextView(this).apply {
            text = "AURA"
            setTextColor(Color.parseColor("#00E5FF")) // matches AppColors.cyan
            gravity = Gravity.CENTER
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
        }
        container.addView(
            label,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )
        applyRoundedCollapsedShape(container)
        return container
    }

    private fun applyRoundedCollapsedShape(view: FrameLayout) {
        val radius = dpToPx(COLLAPSED_SIZE_DP / 2).toFloat()
        val drawable = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = radius
            setColor(Color.parseColor("#CC0B0E14")) // matches overlay host dark surface
        }
        view.background = drawable
    }

    private fun applyExpandedState() {
        val view = overlayView ?: return
        val params = layoutParams ?: return

        if (isExpanded) {
            params.width = dpToPx(EXPANDED_WIDTH_DP)
            params.height = dpToPx(EXPANDED_HEIGHT_DP)
            (view.background as? GradientDrawable)?.cornerRadius = dpToPx(16).toFloat()
        } else {
            params.width = dpToPx(COLLAPSED_SIZE_DP)
            params.height = dpToPx(COLLAPSED_SIZE_DP)
            applyRoundedCollapsedShape(view)
        }

        try {
            windowManager.updateViewLayout(view, params)
        } catch (_: Throwable) {
            // Ignore if detached mid-update.
        }
    }

    // ─── Drag-to-move (also doubles as the tap-to-toggle gesture) ─────

    private fun attachDragHandling(view: View, params: WindowManager.LayoutParams) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var moved = false

        view.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    if (kotlin.math.abs(dx) > 8 || kotlin.math.abs(dy) > 8) {
                        moved = true
                    }
                    params.x = initialX + dx
                    params.y = initialY + dy
                    posX = params.x
                    posY = params.y
                    try {
                        windowManager.updateViewLayout(v, params)
                    } catch (_: Throwable) {
                        // Ignore if detached mid-drag.
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) {
                        togglePanel()
                    }
                    true
                }
                else -> false
            }
        }
    }

    // ─── Notification (required for a foreground service) ─────────────

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(NOTIFICATION_CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    "AURA Floating Assistant",
                    NotificationManager.IMPORTANCE_MIN
                ).apply {
                    description = "Keeps the AURA floating button available on screen."
                    setShowBadge(false)
                }
                manager.createNotificationChannel(channel)
            }
        }

        val contentIntent = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(
                this, 0, it,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("AURA")
            .setContentText("Floating assistant is active")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .apply { contentIntent?.let { setContentIntent(it) } }
            .build()
    }

    private fun dpToPx(dp: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            resources.displayMetrics
        ).toInt()
    }
}
