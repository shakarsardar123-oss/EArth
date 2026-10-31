package com.texo.texo

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.Point
import android.graphics.SweepGradient
import android.os.Build
import android.view.Gravity
import android.provider.Settings
import android.view.View
import android.view.WindowManager
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.DecelerateInterpolator

/**
 * The screen-edge flash that plays when the assistant gesture (long press on
 * Home) is used: a soft multi-colour light that rises along the edges of the
 * screen, slowly circles, then fades away. Drawn in a system overlay window,
 * so no activity of the app is opened.
 */
class TexoGlowView(context: Context) : View(context) {

    private val density = resources.displayMetrics.density
    private fun dp(v: Float): Float = v * density

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val rect = RectF()
    private var shader: SweepGradient? = null
    private var ended = false

    private val colors = intArrayOf(
        Color.parseColor("#4285F4"),
        Color.parseColor("#9B72CB"),
        Color.parseColor("#D96570"),
        Color.parseColor("#F6B26B"),
        Color.parseColor("#34A8EB"),
        Color.parseColor("#4285F4"),
    )

    // Wide, faint layers first, thin bright layer last = a soft glow.
    private val widths = floatArrayOf(60f, 38f, 22f, 11f, 4f)
    private val alphas = floatArrayOf(0.12f, 0.20f, 0.36f, 0.62f, 0.95f)

    init {
        // The glow is painted ONCE into a GPU texture. After that only its
        // opacity / scale change, which the GPU does without redrawing the
        // gradient strokes every frame: smooth and cheap even on slow phones.
        setLayerType(LAYER_TYPE_HARDWARE, null)
        alpha = 0f
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        shader = SweepGradient(w / 2f, h / 2f, colors, null)
    }

    override fun onDraw(canvas: Canvas) {
        val sh = shader ?: return
        paint.shader = sh
        val corner = dp(46f)
        rect.set(0f, 0f, width.toFloat(), height.toFloat())
        for (i in widths.indices) {
            paint.strokeWidth = dp(widths[i])
            paint.alpha = (alphas[i] * 255f).toInt().coerceIn(0, 255)
            canvas.drawRoundRect(rect, corner, corner, paint)
        }
    }

    fun start(onEnd: () -> Unit) {
        scaleX = 1.06f
        scaleY = 1.06f
        animate()
            .alpha(1f)
            .scaleX(1f)
            .scaleY(1f)
            .setDuration(420L)
            .setInterpolator(DecelerateInterpolator(2f))
            .withEndAction {
                animate()
                    .alpha(0f)
                    .setStartDelay(850L)
                    .setDuration(560L)
                    .setInterpolator(AccelerateDecelerateInterpolator())
                    .withEndAction {
                        if (!ended) {
                            ended = true
                            onEnd()
                        }
                    }
                    .start()
            }
            .start()
    }

    override fun onDetachedFromWindow() {
        ended = true
        animate().cancel()
        super.onDetachedFromWindow()
    }
}

object TexoGlow {
    fun canShow(context: Context): Boolean = Settings.canDrawOverlays(context)

    @Suppress("DEPRECATION")
    private fun realScreenSize(context: Context, wm: WindowManager): Point {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val b = wm.maximumWindowMetrics.bounds
                Point(b.width(), b.height())
            } else {
                val p = Point()
                wm.defaultDisplay.getRealSize(p)
                p
            }
        } catch (_: Throwable) {
            val m = context.resources.displayMetrics
            Point(m.widthPixels, m.heightPixels)
        }
    }

    /** Plays the flash; [onDone] runs when it has fully faded out (or could not be shown). */
    fun play(context: Context, onDone: () -> Unit) {
        val app = context.applicationContext
        if (!canShow(app)) {
            onDone()
            return
        }
        val wm = app.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val view = TexoGlowView(app)
        @Suppress("DEPRECATION")
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }
        // MATCH_PARENT stops at the navigation bar on many phones, so use the
        // real display size (status bar + navigation bar included).
        val size = realScreenSize(app, wm)
        val lp = WindowManager.LayoutParams(
            size.x,
            size.y,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT,
        )
        lp.gravity = Gravity.TOP or Gravity.START
        lp.x = 0
        lp.y = 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            lp.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lp.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        try {
            wm.addView(view, lp)
        } catch (_: Throwable) {
            onDone()
            return
        }
        view.start {
            try {
                wm.removeView(view)
            } catch (_: Throwable) {
            }
            onDone()
        }
    }
}
