package com.texo.texo

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
 * This version keeps the existing native placeholder UI, but reports
 * the REAL result of WindowManager.addView() to the Dart side.
 */
class FloatingTexoOverlayService : Service() {

    inner class LocalBinder : Binder() {
        fun service(): FloatingTexoOverlayService = this@FloatingTexoOverlayService
    }

    private val binder = LocalBinder()

    private lateinit var windowManager: WindowManager

    private var overlayView: FrameLayout? = null
    private var layoutParams: WindowManager.LayoutParams? = null

    private var isExpanded = false
    private var isShowing = false

    private var posX = 0
    private var posY = 0

    private var lastOverlayError: String? = null

    companion object {
        const val EXTRA_POS_X_DP = "posXDp"
        const val EXTRA_POS_Y_DP = "posYDp"

        private const val NOTIFICATION_CHANNEL_ID = "texo_floating_overlay"
        private const val NOTIFICATION_ID = 4201

        private const val COLLAPSED_SIZE_DP = 56
        private const val EXPANDED_WIDTH_DP = 280
        private const val EXPANDED_HEIGHT_DP = 400
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()

        windowManager =
            getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        startForeground(
            NOTIFICATION_ID,
            buildNotification(),
        )

        if (overlayView == null) {
            val xDp =
                intent?.getIntExtra(
                    EXTRA_POS_X_DP,
                    16,
                ) ?: 16

            val yDp =
                intent?.getIntExtra(
                    EXTRA_POS_Y_DP,
                    100,
                ) ?: 100

            showOverlayInternal(xDp, yDp)
        }

        return START_STICKY
    }

    override fun onDestroy() {
        removeOverlayInternal()
        super.onDestroy()
    }

    fun isOverlayShowing(): Boolean = isShowing

    fun overlayError(): String? = lastOverlayError

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

    fun updatePosition(
        xDp: Int,
        yDp: Int,
    ) {
        val view = overlayView ?: return
        val params = layoutParams ?: return

        posX = dpToPx(xDp)
        posY = dpToPx(yDp)

        params.x = posX
        params.y = posY

        try {
            windowManager.updateViewLayout(view, params)
        } catch (_: Throwable) {
        }
    }

    fun togglePanel(): Boolean {
        isExpanded = !isExpanded
        applyExpandedState()
        return isExpanded
    }

    private fun showOverlayInternal(
        xDp: Int,
        yDp: Int,
    ) {
        lastOverlayError = null
        isShowing = false

        posX = dpToPx(xDp)
        posY = dpToPx(yDp)

        val view = buildOverlayView()
        overlayView = view

        val type =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }

        val params =
            WindowManager.LayoutParams(
                dpToPx(COLLAPSED_SIZE_DP),
                dpToPx(COLLAPSED_SIZE_DP),
                type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT,
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
            lastOverlayError = null
        } catch (error: Throwable) {
            isShowing = false

            lastOverlayError =
                buildString {
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

            overlayView = null
            layoutParams = null
        }
    }

    private fun removeOverlayInternal() {
        val view = overlayView ?: return

        try {
            windowManager.removeView(view)
        } catch (_: Throwable) {
        }

        overlayView = null
        layoutParams = null

        isShowing = false
        isExpanded = false
        lastOverlayError = null
    }

    private fun buildOverlayView(): FrameLayout {
        val container = FrameLayout(this).apply {
            setPadding(
                dpToPx(2),
                dpToPx(2),
                dpToPx(2),
                dpToPx(2),
            )
        }

        val orb =
            TextView(this).apply {
                text = "A"
                setTextColor(Color.parseColor("#00E5FF"))
                gravity = Gravity.CENTER
                setTextSize(
                    TypedValue.COMPLEX_UNIT_SP,
                    20f,
                )
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(Color.parseColor("#151A23"))
                    setStroke(
                        dpToPx(1),
                        Color.parseColor("#00E5FF"),
                    )
                }
                elevation = dpToPx(4).toFloat()
            }

        container.addView(
            orb,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )

        applyRoundedCollapsedShape(container)

        return container
    }

    private fun applyRoundedCollapsedShape(
        view: FrameLayout,
    ) {
        val radius =
            dpToPx(COLLAPSED_SIZE_DP / 2).toFloat()

        val drawable =
            GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#0B0E14"))
                setStroke(
                    dpToPx(1),
                    Color.parseColor("#6633CCFF"),
                )
                cornerRadius = radius
            }

        view.background = drawable
    }

    private fun applyExpandedState() {
        val view = overlayView ?: return
        val params = layoutParams ?: return

        if (isExpanded) {
            params.width = dpToPx(EXPANDED_WIDTH_DP)
            params.height = dpToPx(EXPANDED_HEIGHT_DP)

            (view.background as? GradientDrawable)
                ?.cornerRadius = dpToPx(16).toFloat()
        } else {
            params.width = dpToPx(COLLAPSED_SIZE_DP)
            params.height = dpToPx(COLLAPSED_SIZE_DP)

            applyRoundedCollapsedShape(view)
        }

        try {
            windowManager.updateViewLayout(view, params)
        } catch (_: Throwable) {
        }
    }

    private fun attachDragHandling(
        view: View,
        params: WindowManager.LayoutParams,
    ) {
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
                    val dx =
                        (event.rawX - initialTouchX).toInt()

                    val dy =
                        (event.rawY - initialTouchY).toInt()

                    if (
                        kotlin.math.abs(dx) > 8 ||
                        kotlin.math.abs(dy) > 8
                    ) {
                        moved = true
                    }

                    params.x = initialX + dx
                    params.y = initialY + dy

                    posX = params.x
                    posY = params.y

                    try {
                        windowManager.updateViewLayout(
                            v,
                            params,
                        )
                    } catch (_: Throwable) {
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

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager =
                getSystemService(
                    Context.NOTIFICATION_SERVICE,
                ) as NotificationManager

            if (
                manager.getNotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                ) == null
            ) {
                val channel =
                    NotificationChannel(
                        NOTIFICATION_CHANNEL_ID,
                        "TEXO Floating Assistant",
                        NotificationManager.IMPORTANCE_MIN,
                    ).apply {
                        description =
                            "Keeps the TEXO floating button available on screen."

                        setShowBadge(false)
                    }

                manager.createNotificationChannel(channel)
            }
        }

        val contentIntent =
            packageManager
                .getLaunchIntentForPackage(packageName)
                ?.let {
                    PendingIntent.getActivity(
                        this,
                        0,
                        it,
                        PendingIntent.FLAG_IMMUTABLE or
                            PendingIntent.FLAG_UPDATE_CURRENT,
                    )
                }

        val builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(
                    this,
                    NOTIFICATION_CHANNEL_ID,
                )
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }

        return builder
            .setContentTitle("TEXO")
            .setContentText("Floating assistant is active")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .apply {
                contentIntent?.let {
                    setContentIntent(it)
                }
            }
            .build()
    }

    private fun dpToPx(dp: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            resources.displayMetrics,
        ).toInt()
}
