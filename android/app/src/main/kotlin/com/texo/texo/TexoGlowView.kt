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
import android.view.animation.LinearInterpolator
import kotlin.math.pow

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
    private val matrix = Matrix()
    private var shader: SweepGradient? = null
    private var level = 0f
    private var spin = 0f
    private var animator: ValueAnimator? = null
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
    private val widths = floatArrayOf(72f, 50f, 34f, 21f, 12f, 5f)
    private val alphas = floatArrayOf(0.10f, 0.14f, 0.20f, 0.32f, 0.55f, 0.95f)

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        shader = SweepGradient(w / 2f, h / 2f, colors, null)
    }

    override fun onDraw(canvas: Canvas) {
        val sh = shader ?: return
        if (level <= 0.001f) return
        val w = width.toFloat()
        val h = height.toFloat()
        matrix.setRotate(spin, w / 2f, h / 2f)
        sh.setLocalMatrix(matrix)
        paint.shader = sh
        val corner = dp(46f)
        rect.set(0f, 0f, w, h)
        for (i in widths.indices) {
            paint.strokeWidth = dp(widths[i]) * (0.55f + 0.45f * level)
            paint.alpha = (alphas[i] * level * 255f).toInt().coerceIn(0, 255)
            canvas.drawRoundRect(rect, corner, corner, paint)
        }
    }

    fun start(onEnd: () -> Unit) {
        val a = ValueAnimator.ofFloat(0f, 1f)
        a.duration = 1600L
        a.interpolator = LinearInterpolator()
        a.addUpdateListener {
            val t = it.animatedValue as Float
            level = when {
                t < 0.25f -> 1f - (1f - t / 0.25f).pow(3)
                t < 0.55f -> 1f
                else -> {
                    val x = (t - 0.55f) / 0.45f
                    1f - x * x * (3f - 2f * x)
                }
            }
            spin = t * 480f
            invalidate()
        }
        a.addListener(object : AnimatorListenerAdapter() {
            override fun onAnimationEnd(animation: Animator) {
                if (!ended) {
                    ended = true
                    onEnd()
                }
            }
        })
        animator = a
        a.start()
    }

    override fun onDetachedFromWindow() {
        ended = true
        animator?.cancel()
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
