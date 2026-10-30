package com.texo.texo

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.TimeInterpolator
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PathMeasure
import android.graphics.PointF
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.os.SystemClock
import android.text.Layout
import android.text.StaticLayout
import android.text.TextDirectionHeuristics
import android.text.TextPaint
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.animation.PathInterpolator
import android.view.View
import kotlin.math.PI
import kotlin.math.ceil
import kotlin.math.exp
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

/**
 * TEXO overlay: a dark glass pill (emoji, voice ribbon, mic / mute / close),
 * a tools tray that opens after holding the pill for 2 seconds, and a
 * subtitles card. Everything is drawn on a Canvas; the Dart side only sends
 * state (mode, level, emoji, flags) through [applyState].
 */
class TexoOverlayView(context: Context) : View(context) {

    interface Listener {
        fun onAction(action: String)
    }

    var listener: Listener? = null

    private val density = resources.displayMetrics.density
    private fun dp(v: Float): Float = v * density

    // ---- state ---------------------------------------------------------------
    private var mode = 0 // 0 listening, 1 thinking, 2 speaking
    private var targetLevel = 0f
    private var level = 0f
    private var lastLevelAt = 0L
    private var emoji = "\uD83D\uDE42"
    private var emojiChangedAt = 0L
    private var micOff = false
    private var muted = false
    private var subsOn = false
    // 0 = under the pill (top), 1 = caption bar at the bottom, 2 = free (drag anywhere)
    private var subsMode = 0
    private var subsLong = false
    private var subsSwiping = false
    private var subsBaseX = 0f
    private fun topSubs(): Boolean = subsOn && subsMode == 0
    private var transOn = false
    private var guideOn = false
    private var ku = true
    private var youText = ""
    private var aiText = ""
    private var trayOpen = false
    private var pillHidden = false
    private var hiding = false
    private var downX = 0f
    private var downY = 0f

    private var pressedKey: String? = null
    private var holding = false
    private var holdStartAt = 0L

    private val t0 = SystemClock.uptimeMillis()
    private var lastFrame = t0

    // ---- open / close animation (grows out of the camera, shrinks back) ------
    private var appear = 0f // 0 = tucked into the camera, 1 = fully open
    private var appearAnim: ValueAnimator? = null
    private var closing = false
    private val openEase = PathInterpolator(0.16f, 1f, 0.3f, 1f)
    private val closeEase = PathInterpolator(0.5f, 0f, 0.75f, 0f)

    private fun runAppear(to: Float, ms: Long, ease: TimeInterpolator, onEnd: (() -> Unit)?) {
        appearAnim?.cancel()
        val a = ValueAnimator.ofFloat(appear, to)
        a.duration = ms
        a.interpolator = ease
        a.addUpdateListener {
            appear = it.animatedValue as Float
            postInvalidateOnAnimation()
        }
        a.addListener(object : AnimatorListenerAdapter() {
            private var cancelled = false
            override fun onAnimationCancel(animation: Animator) { cancelled = true }
            override fun onAnimationEnd(animation: Animator) {
                if (!cancelled) onEnd?.invoke()
            }
        })
        appearAnim = a
        a.start()
    }

    fun animateOut(onEnd: () -> Unit) {
        if (closing) { onEnd(); return }
        closing = true
        runAppear(0f, 380L, closeEase, onEnd)
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        appear = 0f
        closing = false
        runAppear(1f, 700L, openEase, null)
    }

    // ---- geometry (filled by layoutGeo) -------------------------------------------
    private val pillRect = RectF()
    private val emojiC = PointF()
    private var emojiR = 0f
    private val micC = PointF()
    private val spkC = PointF()
    private val closeC = PointF()
    private var btnR = 0f
    private val holdRect = RectF()
    private val trayRects = arrayOf(RectF(), RectF(), RectF())
    private val trayKeys = arrayOf("subs", "trans", "guide")
    private val trayRect = RectF()
    private val subsRect = RectF()

    private var captionLayout: StaticLayout? = null
    private var captionBuilt = ""
    private val capPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
    private var youLayout: StaticLayout? = null
    private var aiLayout: StaticLayout? = null
    private var layoutWidth = -1
    private var layoutDirty = true

    // ---- paints ---------------------------------------------------------------------
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val emojiPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER }
    private val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        color = Color.parseColor("#C4BEE4")
    }
    private val ip = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        strokeWidth = 1.9f
    }
    private val ipText = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER }
    private val tmpRect = RectF()
    private val tmpPath = Path()

    private val youPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#CCEDEAF8") }
    private val aiPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
    private val tagPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { isFakeBoldText = true }

    private val ringColors = intArrayOf(
        Color.parseColor("#5DD6FF"),
        Color.parseColor("#C084FC"),
        Color.parseColor("#FFC46B"),
        Color.parseColor("#8A8FA8"),
    )
    private val waveColors = arrayOf(
        intArrayOf(Color.parseColor("#5DD6FF"), Color.parseColor("#A78BFA"), Color.parseColor("#F472B6")),
        intArrayOf(
            Color.parseColor("#F472B6"),
            Color.parseColor("#A78BFA"),
            Color.parseColor("#38BDF8"),
            Color.parseColor("#34D399"),
        ),
        intArrayOf(Color.parseColor("#FFC46B"), Color.parseColor("#FF7AA8"), Color.parseColor("#A78BFA")),
        intArrayOf(Color.parseColor("#6B7090"), Color.parseColor("#6B7090")),
    )
    // k, speed, phase, amplitude, width (dp), alpha
    private val layers = arrayOf(
        floatArrayOf(0.06f, 1.6f, 0f, 1f, 2.2f, 1f),
        floatArrayOf(0.09f, -2.1f, 2f, 0.7f, 1.6f, 0.8f),
        floatArrayOf(0.045f, 1.1f, 4f, 0.5f, 1.3f, 0.6f),
    )

    companion object {
        private const val PILL_H = 52f
        private const val TRAY_H = 58f
        private const val GAP = 6f
        private const val PAD = 3f
        private const val HOLD_MS = 1000L
        private const val TRAY_IDLE_MS = 15000L
        private const val SWIPE_DP = 36f
        private const val HANDLE_H = 22f
    }

    // ---- public API -------------------------------------------------------------------

    fun applyState(m: Map<*, *>) {
        (m["mode"] as? String)?.let {
            mode = when (it) {
                "thinking" -> 1
                "speaking" -> 2
                else -> 0
            }
        }
        (m["level"] as? Number)?.let {
            targetLevel = it.toFloat().coerceIn(0f, 1f)
            lastLevelAt = SystemClock.uptimeMillis()
        }
        (m["emoji"] as? String)?.let {
            if (it.isNotEmpty() && it != emoji) {
                emoji = it
                emojiChangedAt = SystemClock.uptimeMillis()
            }
        }
        (m["micOff"] as? Boolean)?.let { micOff = it }
        (m["muted"] as? Boolean)?.let { muted = it }
        (m["trans"] as? Boolean)?.let { transOn = it }
        (m["guide"] as? Boolean)?.let { guideOn = it }
        (m["lang"] as? String)?.let { ku = it != "en" }
        var texts = false
        (m["you"] as? String)?.let {
            if (it != youText) {
                youText = it
                texts = true
            }
        }
        (m["ai"] as? String)?.let {
            if (it != aiText) {
                aiText = it
                texts = true
            }
        }
        (m["subs"] as? Boolean)?.let {
            if (it != subsOn) {
                subsOn = it
                layoutDirty = true
                requestLayout()
            }
        }
        if (texts) {
            layoutDirty = true
            if (topSubs()) requestLayout()
        }
        invalidate()
    }

    fun subsEnabled(): Boolean = subsOn
    fun subsModeValue(): Int = subsMode
    fun captionNow(): String = captionText()

    fun setSubsMode(m: Int) {
        val v = ((m % 3) + 3) % 3
        if (v == subsMode) return
        subsMode = v
        layoutDirty = true
        requestLayout()
        invalidate()
    }

    fun toggleTray(): Boolean {
        setTray(!trayOpen)
        return trayOpen
    }

    // ---- measuring / geometry ------------------------------------------------------------

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val w = MeasureSpec.getSize(widthMeasureSpec)
        var h = 0f
        if (!pillHidden) {
            h = dp(PILL_H) + 2f * dp(PAD)
            if (trayOpen) h += dp(GAP + TRAY_H)
        } else {
            h = dp(HANDLE_H)
        }
        if (topSubs()) {
            val sh = subsHeight(w)
            if (sh > 0f) h += dp(GAP) + sh
        }
        setMeasuredDimension(w, max(1, ceil(h).toInt()))
    }

    /** What the caption shows: the assistant while it speaks, the user otherwise. */
    private fun captionText(): String = when {
        mode == 2 && aiText.isNotBlank() -> aiText
        mode != 2 && youText.isNotBlank() -> youText
        aiText.isNotBlank() -> aiText
        else -> youText
    }

    private fun ensureLayouts(w: Int) {
        val text = captionText()
        if (!layoutDirty && layoutWidth == w && text == captionBuilt) return
        layoutWidth = w
        layoutDirty = false
        captionBuilt = text
        val inner = max(40, (w - 2f * dp(PAD) - dp(28f)).toInt())
        capPaint.textSize = dp(14f)
        captionLayout =
            if (text.isBlank()) null
            else buildLayout(text, capPaint, inner, Layout.Alignment.ALIGN_CENTER)
    }

    private fun buildLayout(
        text: String,
        paint: TextPaint,
        width: Int,
        align: Layout.Alignment = Layout.Alignment.ALIGN_NORMAL,
    ): StaticLayout {
        return StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
            .setAlignment(align)
            .setTextDirection(TextDirectionHeuristics.FIRSTSTRONG_LTR)
            .setLineSpacing(0f, 1.25f)
            .setMaxLines(4)
            .setEllipsize(android.text.TextUtils.TruncateAt.END)
            .build()
    }

    private fun subsHeight(w: Int): Float {
        ensureLayouts(w)
        val l = captionLayout ?: return 0f
        return l.height + dp(16f)
    }

    private fun layoutGeo(w: Float) {
        val pad = dp(PAD)
        pillRect.set(pad, pad, w - pad, pad + dp(PILL_H))
        val cy = pillRect.centerY()
        emojiR = dp(17f)
        emojiC.set(pillRect.left + dp(8f) + emojiR, cy)
        btnR = dp(14f)
        closeC.set(pillRect.right - dp(8f) - btnR, cy)
        spkC.set(closeC.x - 2f * btnR - dp(6f), cy)
        micC.set(spkC.x - 2f * btnR - dp(6f), cy)
        holdRect.set(emojiC.x - emojiR, pillRect.top, micC.x - btnR - dp(4f), pillRect.bottom)
        if (trayOpen) {
            val top = pillRect.bottom + dp(GAP)
            trayRect.set(pad, top, w - pad, top + dp(TRAY_H))
            val slot = trayRect.width() / 3f
            val bw = dp(88f)
            val bh = dp(46f)
            for (i in 0..2) {
                val cx = trayRect.left + slot * (i + 0.5f)
                trayRects[i].set(cx - bw / 2f, trayRect.centerY() - bh / 2f, cx + bw / 2f, trayRect.centerY() + bh / 2f)
            }
        }
    }

    // ---- touch -----------------------------------------------------------------------------

    private fun hit(x: Float, y: Float): String? {
        if (pillHidden) return null
        val slop = btnR + dp(5f)
        if (hypot(x - micC.x, y - micC.y) <= slop) return "mic"
        if (hypot(x - spkC.x, y - spkC.y) <= slop) return "mute"
        if (hypot(x - closeC.x, y - closeC.y) <= slop) return "close"
        if (trayOpen) {
            for (i in 0..2) if (trayRects[i].contains(x, y)) return trayKeys[i]
        }
        if (holdRect.contains(x, y)) return "hold"
        return null
    }

    private val holdRunnable = Runnable {
        holding = false
        pressedKey = null
        performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
        if (trayOpen) {
            setTray(false)
            listener?.onAction("tray_close")
        } else {
            setTray(true)
            listener?.onAction("tray_open")
        }
    }
    private val trayHideRunnable = Runnable { setTray(false) }
    private fun cycleSubsMode(dir: Int) {
        subsMode = ((subsMode + dir) % 3 + 3) % 3
        if (!subsOn) subsOn = true
        performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
        layoutDirty = true
        requestLayout()
        invalidate()
        listener?.onAction("subsmode=" + subsMode)
        listener?.onAction("subs=1")
    }

    private fun setTray(open: Boolean) {
        removeCallbacks(trayHideRunnable)
        if (open == trayOpen) {
            if (open) postDelayed(trayHideRunnable, TRAY_IDLE_MS)
            return
        }
        trayOpen = open
        requestLayout()
        invalidate()
        if (open) postDelayed(trayHideRunnable, TRAY_IDLE_MS)
    }

    private fun cancelHold() {
        removeCallbacks(holdRunnable)
        holding = false
    }

    private fun hidePill() {
        if (hiding || pillHidden) return
        hiding = true
        cancelHold()
        pressedKey = null
        removeCallbacks(trayHideRunnable)
        trayOpen = false
        requestLayout()
        listener?.onAction("hide")
        // Shrinks back into the camera, then only a small handle stays so the
        // pill can always be pulled back down (or tapped).
        runAppear(0f, 320L, closeEase) {
            pillHidden = true
            hiding = false
            requestLayout()
            invalidate()
        }
    }

    private fun showPill() {
        hiding = false
        pillHidden = false
        requestLayout()
        invalidate()
        runAppear(1f, 520L, openEase, null)
        listener?.onAction("show")
    }

    private fun fire(key: String) {
        when (key) {
            "mic" -> {
                micOff = !micOff
                listener?.onAction("mic=" + (if (micOff) "1" else "0"))
            }
            "mute" -> {
                muted = !muted
                listener?.onAction("mute=" + (if (muted) "1" else "0"))
            }
            "close" -> listener?.onAction("close")
            "subs" -> {
                subsOn = !subsOn
                layoutDirty = true
                requestLayout()
                listener?.onAction("subs=" + (if (subsOn) "1" else "0"))
                setTray(true)
            }
            "trans" -> {
                transOn = !transOn
                listener?.onAction("translate=" + (if (transOn) "1" else "0"))
                setTray(true)
            }
            "guide" -> {
                guideOn = !guideOn
                listener?.onAction("guide=" + (if (guideOn) "1" else "0"))
                setTray(true)
            }
        }
    }

    override fun onTouchEvent(e: MotionEvent): Boolean {
        layoutGeo(width.toFloat())
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                val k = hit(e.x, e.y)
                pressedKey = k
                downX = e.x
                downY = e.y
                subsLong = false
                if (k == "hold") {
                    holding = true
                    holdStartAt = SystemClock.uptimeMillis()
                    postDelayed(holdRunnable, HOLD_MS)
                } else if (k == "subs") {
                    subsSwiping = false
                    subsBaseX = e.x
                    setTray(true)
                } else if (trayOpen) {
                    setTray(true)
                }
                invalidate()
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val dy = e.y - downY
                if (!pillHidden && !hiding && dy < -dp(SWIPE_DP)) {
                    hidePill()
                    return true
                }
                if (pillHidden && dy > dp(SWIPE_DP)) {
                    showPill()
                    return true
                }
                // Swipe right / left on the subtitles button: next / previous mode.
                if (pressedKey == "subs" || subsSwiping) {
                    val dx = e.x - subsBaseX
                    if (kotlin.math.abs(dx) > dp(26f)) {
                        subsSwiping = true
                        subsLong = true
                        pressedKey = "subs"
                        cycleSubsMode(if (dx > 0f) 1 else -1)
                        subsBaseX = e.x
                        return true
                    }
                    if (subsSwiping) return true
                }
                val k = hit(e.x, e.y)
                if (k != pressedKey) {
                    cancelHold()
                    pressedKey = null
                    invalidate()
                }
                return true
            }
            MotionEvent.ACTION_UP -> {
                val k = pressedKey
                cancelHold()
                pressedKey = null
                if (pillHidden) {
                    // A tap on the handle brings the pill back.
                    if (hypot(e.x - downX, e.y - downY) < dp(10f)) showPill()
                } else if (!hiding && !subsLong && k != null && k != "hold") {
                    fire(k)
                }
                subsLong = false
                subsSwiping = false
                invalidate()
                return true
            }
            MotionEvent.ACTION_CANCEL -> {
                cancelHold()
                pressedKey = null
                invalidate()
                return true
            }
        }
        return super.onTouchEvent(e)
    }

    override fun onDetachedFromWindow() {
        appearAnim?.cancel()
        removeCallbacks(holdRunnable)
        removeCallbacks(trayHideRunnable)
        super.onDetachedFromWindow()
    }

    // ---- drawing ---------------------------------------------------------------------------

    private fun visual(): Int = if (mode == 0 && micOff) 3 else mode

    private fun withAlpha(color: Int, a: Float): Int =
        Color.argb((a.coerceIn(0f, 1f) * 255f).toInt(), Color.red(color), Color.green(color), Color.blue(color))

    private fun label(): String = when {
        mode == 0 && micOff -> if (ku) "مایک داخراوە" else "Mic is off"
        mode == 2 && muted -> if (ku) "بێدەنگە — ژێرنووس" else "Muted — subtitles"
        mode == 1 -> if (ku) "بیر دەکەمەوە..." else "Thinking..."
        mode == 2 -> if (ku) "قسە دەکەم..." else "Speaking..."
        else -> if (ku) "گوێم لێتە..." else "Listening..."
    }

    override fun onDraw(canvas: Canvas) {
        val now = SystemClock.uptimeMillis()
        val t = (now - t0) / 1000f
        val dt = min(0.05f, (now - lastFrame) / 1000f)
        lastFrame = now
        if (now - lastLevelAt > 1500L) targetLevel = 0f
        level += (targetLevel - level) * (1f - exp(-dt * (if (targetLevel > level) 14f else 6f)))

        val w = width.toFloat()
        layoutGeo(w)
        if (!pillHidden) {
            val e = appear.coerceIn(0f, 1f)
            if (e < 0.999f) {
                val layer = canvas.saveLayerAlpha(
                    0f, 0f, w, height.toFloat(),
                    (min(1f, e * 2.2f) * 255f).toInt(),
                )
                canvas.translate(0f, -(1f - e) * dp(16f))
                canvas.scale(0.12f + 0.88f * e, 0.30f + 0.70f * e, w / 2f, pillRect.top)
                drawPill(canvas, t, now)
                if (trayOpen) drawTray(canvas)
                canvas.restoreToCount(layer)
            } else {
                drawPill(canvas, t, now)
                if (trayOpen) drawTray(canvas)
            }
        }
        if (pillHidden) drawHandle(canvas, w)
        if (topSubs()) drawSubs(canvas, w)
        // ~60 frames per second while the pill is on screen; when only the
        // handle / caption is shown nothing animates, so no redraw loop at all.
        if (!pillHidden) postInvalidateDelayed(16L)
    }

    private fun drawHandle(c: Canvas, w: Float) {
        val barW = dp(44f)
        val barH = dp(6f)
        val cx = w / 2f
        val top = dp(6f)
        tmpRect.set(cx - barW / 2f, top, cx + barW / 2f, top + barH)
        tmpRect.inset(-dp(6f), -dp(3f))
        fill.shader = null
        fill.color = Color.parseColor("#E6000000")
        c.drawRoundRect(tmpRect, dp(9f), dp(9f), fill)
        tmpRect.set(cx - barW / 2f, top, cx + barW / 2f, top + barH)
        fill.color = withAlpha(Color.WHITE, 0.6f)
        c.drawRoundRect(tmpRect, barH / 2f, barH / 2f, fill)
    }

    private fun gradientFill(r: RectF, top: Int, bottom: Int) {
        // An old, faded colour on this paint would fade the gradient too.
        fill.color = Color.BLACK
        fill.shader = LinearGradient(0f, r.top, 0f, r.bottom, top, bottom, Shader.TileMode.CLAMP)
    }

    private fun drawPill(c: Canvas, t: Float, now: Long) {
        val v = visual()
        val r = pillRect.height() / 2f

        stroke.shader = null
        stroke.color = withAlpha(ringColors[v], 0.16f)
        stroke.strokeWidth = dp(3f)
        tmpRect.set(pillRect)
        tmpRect.inset(-dp(1.5f), -dp(1.5f))
        c.drawRoundRect(tmpRect, r + dp(1.5f), r + dp(1.5f), stroke)

        gradientFill(pillRect, Color.parseColor("#FF0B0B0E"), Color.parseColor("#FF000000"))
        c.drawRoundRect(pillRect, r, r, fill)
        fill.shader = null
        stroke.color = withAlpha(Color.WHITE, 0.14f)
        stroke.strokeWidth = dp(1f)
        c.drawRoundRect(pillRect, r, r, stroke)

        if (holding) {
            val prog = ((now - holdStartAt) / HOLD_MS.toFloat()).coerceIn(0f, 1f)
            tmpRect.set(pillRect)
            tmpRect.inset(-dp(2f), -dp(2f))
            val rr = tmpRect.height() / 2f
            tmpPath.reset()
            tmpPath.moveTo(tmpRect.centerX(), tmpRect.top)
            tmpPath.lineTo(tmpRect.right - rr, tmpRect.top)
            tmpPath.arcTo(RectF(tmpRect.right - 2f * rr, tmpRect.top, tmpRect.right, tmpRect.bottom), -90f, 180f)
            tmpPath.lineTo(tmpRect.left + rr, tmpRect.bottom)
            tmpPath.arcTo(RectF(tmpRect.left, tmpRect.top, tmpRect.left + 2f * rr, tmpRect.bottom), 90f, 180f)
            tmpPath.lineTo(tmpRect.centerX(), tmpRect.top)
            val pm = PathMeasure(tmpPath, false)
            val seg = Path()
            pm.getSegment(0f, pm.length * prog, seg, true)
            stroke.color = Color.parseColor("#A78BFA")
            stroke.strokeWidth = dp(3f)
            c.drawPath(seg, stroke)
        }

        drawEmoji(c, v, now)
        drawWave(c, v, t)

        val micBg = if (micOff) Color.parseColor("#33FF5A6E") else Color.parseColor("#295DD6FF")
        val micBorder = if (micOff) Color.parseColor("#80FF788C") else Color.parseColor("#735DD6FF")
        drawButton(c, micC, micBg, micBorder, pressedKey == "mic")
        drawMic(c, micC.x, micC.y, dp(15f), Color.WHITE, micOff)

        val spkBg = if (muted) Color.parseColor("#33FFB454") else Color.parseColor("#1AFFFFFF")
        val spkBorder = if (muted) Color.parseColor("#8CFFC46B") else Color.parseColor("#29FFFFFF")
        drawButton(c, spkC, spkBg, spkBorder, pressedKey == "mute")
        drawSpeaker(c, spkC.x, spkC.y, dp(15f), Color.WHITE, muted)

        drawButton(c, closeC, Color.parseColor("#33FF5A6E"), Color.parseColor("#80FF788C"), pressedKey == "close")
        drawClose(c, closeC.x, closeC.y, dp(13f), Color.parseColor("#FFD3DA"))
    }

    private fun drawEmoji(c: Canvas, v: Int, now: Long) {
        val cx = emojiC.x
        val cy = emojiC.y
        fill.shader = RadialGradient(
            cx - emojiR * 0.3f, cy - emojiR * 0.4f, emojiR * 1.3f,
            withAlpha(Color.WHITE, 0.16f), withAlpha(Color.WHITE, 0.05f), Shader.TileMode.CLAMP,
        )
        c.drawCircle(cx, cy, emojiR, fill)
        fill.shader = null
        stroke.shader = null
        stroke.color = withAlpha(ringColors[v], 0.22f)
        stroke.strokeWidth = dp(4f)
        c.drawCircle(cx, cy, emojiR, stroke)
        stroke.color = ringColors[v]
        stroke.strokeWidth = dp(2f)
        c.drawCircle(cx, cy, emojiR - dp(1f), stroke)

        val p = min(1f, (now - emojiChangedAt) / 550f)
        val tt = p - 1f
        val s = if (p >= 1f) 1f else 0.3f + 0.7f * (tt * tt * (3.5f * tt + 2.5f) + 1f)
        c.save()
        c.scale(s, s, cx, cy)
        emojiPaint.textSize = dp(19f)
        val fm = emojiPaint.fontMetrics
        c.drawText(emoji, cx, cy - (fm.ascent + fm.descent) / 2f, emojiPaint)
        c.restore()

        if (muted) {
            val bx = cx + emojiR * 0.72f
            val by = cy + emojiR * 0.72f
            fill.color = Color.parseColor("#FFB454")
            c.drawCircle(bx, by, dp(7f), fill)
            ip.color = Color.parseColor("#3A2300")
            ip.strokeWidth = dp(2f)
            c.drawLine(bx - dp(2.8f), by - dp(2.8f), bx + dp(2.8f), by + dp(2.8f), ip)
            ip.strokeWidth = 1.9f
        }
    }

    private fun drawWave(c: Canvas, v: Int, t: Float) {
        val wL = emojiC.x + emojiR + dp(10f)
        val wR = micC.x - btnR - dp(8f)
        val wW = wR - wL
        if (wW < dp(30f)) return
        val cy = pillRect.centerY() - dp(5f)
        val eff = when {
            v == 3 -> 0.02f
            v == 1 -> 0.16f + 0.05f * sin(t * 2.4f)
            else -> level
        } * (if (muted && mode == 2) 0.35f else 1f)
        val amp = dp(11f)
        val wDp = wW / density

        stroke.shader = LinearGradient(wL, 0f, wR, 0f, waveColors[v], null, Shader.TileMode.CLAMP)
        for (L in layers) {
            for (pass in 0..1) {
                tmpPath.reset()
                var x = 0f
                var first = true
                while (x <= wDp) {
                    val env = sin(PI.toFloat() * x / wDp).coerceAtLeast(0f).pow(1.1f)
                    val y = cy + sin(x * L[0] + t * L[1] + L[2]) * amp * L[3] * env * (0.10f + 0.90f * eff)
                    if (first) {
                        tmpPath.moveTo(wL + x * density, y)
                        first = false
                    } else {
                        tmpPath.lineTo(wL + x * density, y)
                    }
                    x += 2f
                }
                stroke.strokeWidth = if (pass == 0) dp(6f) else dp(L[4])
                stroke.alpha = ((if (pass == 0) 0.14f else 0.95f) * L[5] * 255f).toInt()
                c.drawPath(tmpPath, stroke)
            }
        }
        stroke.shader = null
        stroke.alpha = 255

        if (v != 3) {
            for (i in 0..2) {
                val p = (t * 0.22f + i / 3f) % 1f
                val x = p * wDp
                val env = sin(PI.toFloat() * x / wDp).coerceAtLeast(0f).pow(1.1f)
                val l0 = layers[0]
                val y = cy + sin(x * l0[0] + t * l0[1] + l0[2]) * amp * l0[3] * env * (0.10f + 0.90f * eff)
                val al = sin(PI.toFloat() * p) * 0.9f
                val px = wL + x * density
                fill.color = withAlpha(Color.WHITE, al * 0.25f)
                c.drawCircle(px, y, dp(6f), fill)
                fill.color = withAlpha(Color.WHITE, al)
                c.drawCircle(px, y, dp(2f), fill)
            }
        }

        labelPaint.textSize = dp(10f)
        c.drawText(label(), (wL + wR) / 2f, pillRect.centerY() + dp(15f), labelPaint)
    }

    private fun drawButton(c: Canvas, p: PointF, bg: Int, border: Int, pressed: Boolean) {
        val r = if (pressed) btnR * 0.92f else btnR
        fill.shader = null
        fill.color = bg
        c.drawCircle(p.x, p.y, r, fill)
        stroke.shader = null
        stroke.color = border
        stroke.strokeWidth = dp(1f)
        c.drawCircle(p.x, p.y, r, stroke)
    }

    private inline fun icon(c: Canvas, cx: Float, cy: Float, size: Float, color: Int, block: () -> Unit) {
        c.save()
        c.translate(cx - size / 2f, cy - size / 2f)
        c.scale(size / 24f, size / 24f)
        ip.color = color
        ip.strokeWidth = 1.9f
        block()
        c.restore()
    }

    private fun drawMic(c: Canvas, cx: Float, cy: Float, size: Float, color: Int, off: Boolean) {
        icon(c, cx, cy, size, color) {
            tmpRect.set(9f, 3f, 15f, 15f)
            c.drawRoundRect(tmpRect, 3f, 3f, ip)
            tmpRect.set(5f, 4f, 19f, 18f)
            c.drawArc(tmpRect, 0f, 180f, false, ip)
            c.drawLine(12f, 18f, 12f, 21f, ip)
            if (off) {
                ip.color = Color.parseColor("#FF8FA0")
                ip.strokeWidth = 2.4f
                c.drawLine(4f, 4f, 20f, 20f, ip)
            }
        }
    }

    private fun drawSpeaker(c: Canvas, cx: Float, cy: Float, size: Float, color: Int, off: Boolean) {
        icon(c, cx, cy, size, color) {
            tmpPath.reset()
            tmpPath.moveTo(5f, 10f)
            tmpPath.lineTo(5f, 14f)
            tmpPath.lineTo(8f, 14f)
            tmpPath.lineTo(12f, 17.5f)
            tmpPath.lineTo(12f, 6.5f)
            tmpPath.lineTo(8f, 10f)
            tmpPath.close()
            c.drawPath(tmpPath, ip)
            if (!off) {
                tmpRect.set(12f - 4.5f, 12f - 4.5f, 12f + 4.5f, 12f + 4.5f)
                c.drawArc(tmpRect, -42f, 84f, false, ip)
                tmpRect.set(12f - 7.5f, 12f - 7.5f, 12f + 7.5f, 12f + 7.5f)
                c.drawArc(tmpRect, -42f, 84f, false, ip)
            } else {
                ip.color = Color.parseColor("#FFC46B")
                ip.strokeWidth = 2.4f
                c.drawLine(4f, 4f, 20f, 20f, ip)
            }
        }
    }

    private fun drawClose(c: Canvas, cx: Float, cy: Float, size: Float, color: Int) {
        icon(c, cx, cy, size, color) {
            ip.strokeWidth = 2.3f
            c.drawLine(6f, 6f, 18f, 18f, ip)
            c.drawLine(18f, 6f, 6f, 18f, ip)
        }
    }

    private fun drawTray(c: Canvas) {
        val rad = dp(20f)
        gradientFill(trayRect, Color.parseColor("#FF0B0B0E"), Color.parseColor("#FF000000"))
        c.drawRoundRect(trayRect, rad, rad, fill)
        fill.shader = null
        stroke.shader = null
        stroke.color = withAlpha(Color.WHITE, 0.14f)
        stroke.strokeWidth = dp(1f)
        c.drawRoundRect(trayRect, rad, rad, stroke)

        val active = booleanArrayOf(subsOn, transOn, guideOn)
        val subsNamesKu = arrayOf("ژێرنووس: سەرەوە", "ژێرنووس: کاپشن", "ژێرنووس: ئازاد")
        val subsNamesEn = arrayOf("Subs: top", "Subs: caption", "Subs: free")
        val names = if (ku) arrayOf(subsNamesKu[subsMode], "تەرجومەی شاشە", "ڕێنمایی")
        else arrayOf(subsNamesEn[subsMode], "Translate screen", "Guide me")
        labelPaint.textSize = dp(10f)
        labelPaint.isFakeBoldText = true
        for (i in 0..2) {
            val r = trayRects[i]
            val on = active[i]
            val pressed = pressedKey == trayKeys[i]
            tmpRect.set(r)
            if (pressed) tmpRect.inset(dp(2f), dp(2f))
            if (on) {
                fill.shader = LinearGradient(
                    tmpRect.left, tmpRect.top, tmpRect.right, tmpRect.bottom,
                    Color.parseColor("#8C8B5CF6"), Color.parseColor("#4DA78BFA"), Shader.TileMode.CLAMP,
                )
            } else {
                fill.color = Color.parseColor("#12FFFFFF")
            }
            c.drawRoundRect(tmpRect, dp(14f), dp(14f), fill)
            fill.shader = null
            stroke.color = if (on) Color.parseColor("#E6A78BFA") else withAlpha(Color.WHITE, 0.14f)
            c.drawRoundRect(tmpRect, dp(14f), dp(14f), stroke)

            val fg = if (on) Color.WHITE else Color.parseColor("#D5D0F2")
            val ix = r.centerX()
            val iy = r.top + dp(15f)
            when (i) {
                0 -> drawSubsModeIcon(c, ix, iy, dp(18f), fg)
                1 -> drawTransIcon(c, ix, iy, dp(18f), fg)
                else -> drawGuideIcon(c, ix, iy, dp(18f), fg)
            }
            if (i == 0) {
                for (d in 0..2) {
                    fill.shader = null
                    fill.color = withAlpha(Color.WHITE, if (d == subsMode) 0.95f else 0.28f)
                    c.drawCircle(r.right - dp(22f) + d * dp(6f), r.top + dp(8f), dp(1.8f), fill)
                }
            }
            labelPaint.color = fg
            c.drawText(names[i], r.centerX(), r.bottom - dp(8f), labelPaint)
        }
        labelPaint.isFakeBoldText = false
        labelPaint.color = Color.parseColor("#C4BEE4")
    }

    // One icon per subtitle mode, so the button itself tells where the text will be.
    private fun drawSubsModeIcon(c: Canvas, cx: Float, cy: Float, size: Float, color: Int) {
        icon(c, cx, cy, size, color) {
            when (subsMode) {
                0 -> { // text under the pill, at the top
                    tmpRect.set(6f, 3f, 18f, 8f)
                    c.drawRoundRect(tmpRect, 2.5f, 2.5f, ip)
                    c.drawLine(5f, 13f, 19f, 13f, ip)
                    c.drawLine(8f, 18f, 16f, 18f, ip)
                }
                1 -> { // caption bar at the bottom
                    tmpRect.set(3f, 12f, 21f, 21f)
                    c.drawRoundRect(tmpRect, 3f, 3f, ip)
                    c.drawLine(7f, 16.5f, 11f, 16.5f, ip)
                    c.drawLine(13f, 16.5f, 17f, 16.5f, ip)
                    c.drawLine(8f, 5f, 16f, 5f, ip)
                }
                else -> { // free: drag anywhere
                    c.drawLine(12f, 3f, 12f, 21f, ip)
                    c.drawLine(3f, 12f, 21f, 12f, ip)
                    c.drawLine(12f, 3f, 9.5f, 5.8f, ip)
                    c.drawLine(12f, 3f, 14.5f, 5.8f, ip)
                    c.drawLine(12f, 21f, 9.5f, 18.2f, ip)
                    c.drawLine(12f, 21f, 14.5f, 18.2f, ip)
                    c.drawLine(3f, 12f, 5.8f, 9.5f, ip)
                    c.drawLine(3f, 12f, 5.8f, 14.5f, ip)
                    c.drawLine(21f, 12f, 18.2f, 9.5f, ip)
                    c.drawLine(21f, 12f, 18.2f, 14.5f, ip)
                }
            }
        }
    }

    private fun drawSubsIcon(c: Canvas, cx: Float, cy: Float, size: Float, color: Int) {
        icon(c, cx, cy, size, color) {
            tmpRect.set(3f, 5f, 21f, 19f)
            c.drawRoundRect(tmpRect, 3.5f, 3.5f, ip)
            c.drawLine(7f, 10.5f, 11f, 10.5f, ip)
            c.drawLine(13f, 10.5f, 17f, 10.5f, ip)
            c.drawLine(7f, 14f, 9.5f, 14f, ip)
            c.drawLine(12f, 14f, 17f, 14f, ip)
        }
    }

    private fun drawTransIcon(c: Canvas, cx: Float, cy: Float, size: Float, color: Int) {
        icon(c, cx, cy, size, color) {
            ipText.color = color
            ipText.isFakeBoldText = true
            ipText.textSize = 13f
            c.drawText("ک", 7.5f, 11.5f, ipText)
            ipText.textSize = 12f
            c.drawText("A", 16.5f, 19.5f, ipText)
            tmpRect.set(3f, 3f, 21f, 21f)
            c.drawArc(tmpRect, 200f, 70f, false, ip)
        }
    }

    private fun drawGuideIcon(c: Canvas, cx: Float, cy: Float, size: Float, color: Int) {
        icon(c, cx, cy, size, color) {
            c.drawCircle(6f, 18f, 2.2f, ip)
            c.drawCircle(18f, 6f, 2.2f, ip)
            tmpPath.reset()
            tmpPath.moveTo(8f, 17.5f)
            tmpPath.cubicTo(14f, 17.5f, 10f, 6.5f, 16f, 6.3f)
            c.drawPath(tmpPath, ip)
        }
    }

    private fun drawSubs(c: Canvas, w: Float) {
        ensureLayouts(w.toInt())
        val l = captionLayout ?: return
        var top = if (pillHidden) dp(HANDLE_H) + dp(GAP) else pillRect.bottom + dp(GAP)
        if (!pillHidden && trayOpen) top = trayRect.bottom + dp(GAP)
        val h = l.height + dp(16f)
        // The plate is only as wide as the text, so it reads like a caption.
        var tw = 0f
        for (i in 0 until l.lineCount) tw = max(tw, l.getLineWidth(i))
        val plateW = min(w - 2f * dp(PAD), tw + dp(28f))
        val left = (w - plateW) / 2f
        subsRect.set(left, top, left + plateW, top + h)
        val rad = dp(14f)
        fill.shader = null
        fill.color = Color.parseColor("#E6000000")
        c.drawRoundRect(subsRect, rad, rad, fill)
        c.save()
        c.translate(subsRect.centerX() - l.width / 2f, top + dp(8f))
        l.draw(c)
        c.restore()
    }
}
