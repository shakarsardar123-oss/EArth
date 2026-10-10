package com.texo.texo

import android.animation.ObjectAnimator
import android.animation.ValueAnimator
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
import android.widget.LinearLayout
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
    private val waveformAnimators = mutableListOf<ObjectAnimator>()
    private var subtitlesEnabled = false
    var onOverlayAction: ((String) -> Unit)? = null

    companion object {
        const val EXTRA_POS_X_DP = "posXDp"
        const val EXTRA_POS_Y_DP = "posYDp"

        private const val NOTIFICATION_CHANNEL_ID = "texo_floating_overlay"
        private const val NOTIFICATION_ID = 4201

        private const val COLLAPSED_WIDTH_DP = 232
        private const val COLLAPSED_SIZE_DP = 56
        private const val EXPANDED_WIDTH_DP = 300
        private const val EXPANDED_HEIGHT_DP = 112
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

        posX = 0
        posY = dpToPx(36)

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
                dpToPx(COLLAPSED_WIDTH_DP),
                dpToPx(COLLAPSED_SIZE_DP),
                type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
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
        stopWaveformAnimations()
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
        return FrameLayout(this).apply {
            setPadding(dpToPx(5), dpToPx(4), dpToPx(5), dpToPx(4))
            isClickable = true
            applyRoundedCollapsedShape(this)
            showCollapsedContent(this)
        }
    }

    private fun makeText(
        text: String,
        color: Int,
        size: Float,
    ): TextView = TextView(this).apply {
        this.text = text
        setTextColor(color)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, size)
        gravity = Gravity.CENTER
        includeFontPadding = false
    }

    private fun stopWaveformAnimations() {
        waveformAnimators.forEach { it.cancel() }
        waveformAnimators.clear()
    }

    private fun makeWaveform(): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            layoutDirection = View.LAYOUT_DIRECTION_LTR

            val heights = listOf(9, 20, 13, 26, 15, 22, 10)
            heights.forEachIndexed { index, height ->
                val bar = View(this@FloatingTexoOverlayService).apply {
                    background = GradientDrawable().apply {
                        shape = GradientDrawable.RECTANGLE
                        cornerRadius = dpToPx(3).toFloat()
                        setColor(Color.parseColor("#55D9FF"))
                    }
                    pivotY = dpToPx(15).toFloat()
                }

                addView(
                    bar,
                    LinearLayout.LayoutParams(
                        dpToPx(3),
                        dpToPx(height),
                    ).apply {
                        marginStart = dpToPx(2)
                        marginEnd = dpToPx(2)
                    },
                )

                val animator = ObjectAnimator.ofFloat(
                    bar, View.SCALE_Y, 0.35f, 1f,
                ).apply {
                    duration = 350L + index * 75L
                    repeatCount = ValueAnimator.INFINITE
                    repeatMode = ValueAnimator.REVERSE
                    startDelay = index * 55L
                }
                waveformAnimators.add(animator)
                animator.start()
            }
        }
    }

    private fun makeActionButton(
        label: String,
        backgroundColor: Int,
        action: () -> Unit,
    ): TextView {
        return makeText(label, Color.WHITE, 11f).apply {
            isClickable = true
            isFocusable = true
            setPadding(dpToPx(4), 0, dpToPx(4), 0)
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(12).toFloat()
                setColor(backgroundColor)
            }
            setOnClickListener { action() }
        }
    }

    private fun showCollapsedContent(container: FrameLayout) {
        stopWaveformAnimations()
        container.removeAllViews()

        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutDirection = View.LAYOUT_DIRECTION_LTR
            setPadding(dpToPx(3), 0, dpToPx(3), 0)
        }

        val endButton = makeText("×", Color.WHITE, 28f).apply {
            isClickable = true
            isFocusable = true
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#E53945"))
            }
            setOnClickListener { onOverlayAction?.invoke("endCall") }
        }

        row.addView(
            endButton,
            LinearLayout.LayoutParams(dpToPx(38), dpToPx(38)).apply {
                marginEnd = dpToPx(10)
            },
        )

        row.addView(
            makeWaveform(),
            LinearLayout.LayoutParams(0, dpToPx(34), 1f),
        )

        row.addView(
            makeText("✨", Color.WHITE, 23f),
            LinearLayout.LayoutParams(dpToPx(35), dpToPx(42)),
        )

        container.addView(
            row,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        applyRoundedCollapsedShape(container)
    }

    private fun showExpandedContent(container: FrameLayout) {
        stopWaveformAnimations()
        container.removeAllViews()

        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutDirection = View.LAYOUT_DIRECTION_LTR
            setPadding(dpToPx(12), dpToPx(7), dpToPx(12), dpToPx(8))
        }

        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutDirection = View.LAYOUT_DIRECTION_LTR
        }

        header.addView(
            makeText("TEXO  •  LIVE", Color.parseColor("#75DFFF"), 12f),
            LinearLayout.LayoutParams(0, dpToPx(28), 1f),
        )
        header.addView(
            makeWaveform(),
            LinearLayout.LayoutParams(dpToPx(72), dpToPx(28)),
        )
        header.addView(
            makeText("✨", Color.WHITE, 21f),
            LinearLayout.LayoutParams(dpToPx(32), dpToPx(28)),
        )

        panel.addView(
            header,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(30),
            ),
        )

        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            layoutDirection = View.LAYOUT_DIRECTION_LTR
        }

        actions.addView(
            makeActionButton("کۆتایی", Color.parseColor("#C62835")) {
                onOverlayAction?.invoke("endCall")
            },
            LinearLayout.LayoutParams(0, dpToPx(42), 1f).apply {
                marginEnd = dpToPx(5)
            },
        )

        actions.addView(
            makeActionButton(
                if (subtitlesEnabled) "ژێرنوس: کراوە" else "ژێرنوس: داخراو",
                Color.parseColor("#202630"),
            ) {
                subtitlesEnabled = !subtitlesEnabled
                onOverlayAction?.invoke("toggleSubtitles")
                showExpandedContent(container)
            },
            LinearLayout.LayoutParams(0, dpToPx(42), 1.2f).apply {
                marginEnd = dpToPx(5)
            },
        )

        actions.addView(
            makeActionButton("کردنەوەی ئەپ", Color.parseColor("#202630")) {
                onOverlayAction?.invoke("openApp")
                packageManager.getLaunchIntentForPackage(packageName)?.let { intent ->
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                }
            },
            LinearLayout.LayoutParams(0, dpToPx(42), 1.1f),
        )

        panel.addView(
            actions,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(44),
            ).apply {
                topMargin = dpToPx(8)
            },
        )

        container.addView(
            panel,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )

        container.background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dpToPx(20).toFloat()
            setColor(Color.BLACK)
            setStroke(dpToPx(1), Color.parseColor("#30435A"))
        }
    }

    private fun applyRoundedCollapsedShape(view: FrameLayout) {
        view.background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dpToPx(COLLAPSED_SIZE_DP / 2).toFloat()
            setColor(Color.BLACK)
            setStroke(dpToPx(1), Color.parseColor("#30435A"))
        }
    }

    private fun applyExpandedState() {
        val view = overlayView ?: return
        val params = layoutParams ?: return

        if (isExpanded) {
            params.width = dpToPx(EXPANDED_WIDTH_DP)
            params.height = dpToPx(EXPANDED_HEIGHT_DP)
            showExpandedContent(view)
        } else {
            params.width = dpToPx(COLLAPSED_WIDTH_DP)
            params.height = dpToPx(COLLAPSED_SIZE_DP)
            showCollapsedContent(view)
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
                    }
                    true
                }

                MotionEvent.ACTION_UP -> {
                    if (!moved) togglePanel()
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
