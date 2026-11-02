package com.texo.texo

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * Hand-drawn animated faces for the pill. Every face behaves like its emoji:
 * the sleeping one closes its eyes after a moment and sends out Z's, the party
 * one blows a horn and throws confetti, the rolling-eyes one really rolls its
 * eyes, and so on. Unknown emoji return false (the caller draws the plain glyph).
 */
object TexoFaces {

    private enum class Kind { SMILE, THINK, TALK, SLEEP, PARTY, STARS, SUN, ROLL, LAUGH, LOVE, SHUSH, SWEAT, SAD }

    private val FACE = Color.parseColor("#FFCB3D")
    private val RIM = Color.parseColor("#E39A00")
    private val DARK = Color.parseColor("#3B2A00")
    private val MOUTH = Color.parseColor("#7A1F1F")
    private val TONGUE = Color.parseColor("#E8666B")
    private val DROP = Color.parseColor("#4FC3F7")

    private val p = Paint(Paint.ANTI_ALIAS_FLAG)
    private val path = Path()
    private val rect = RectF()

    private fun kindOf(e: String): Kind? = when (e) {
        "\uD83D\uDE42", "\uD83D\uDE0A", "\uD83D\uDE0C", "\uD83D\uDC42" -> Kind.SMILE
        "\uD83E\uDD14", "\uD83E\uDDD0", "\uD83E\uDD28", "\uD83D\uDCAD" -> Kind.THINK
        "\uD83D\uDE04", "\uD83D\uDE03", "\uD83D\uDE0E", "\uD83E\uDD13", "\uD83D\uDCA1" -> Kind.TALK
        "\uD83D\uDE34", "\uD83E\uDD71", "\uD83D\uDCA4" -> Kind.SLEEP
        "\uD83E\uDD73" -> Kind.PARTY
        "\uD83E\uDD29" -> Kind.STARS
        "\uD83C\uDF1E" -> Kind.SUN
        "\uD83D\uDE44" -> Kind.ROLL
        "\uD83D\uDE02", "\uD83E\uDD23", "\uD83D\uDE06", "\uD83D\uDE1C" -> Kind.LAUGH
        "\uD83D\uDE0D", "\uD83E\uDD70" -> Kind.LOVE
        "\uD83E\uDD2B", "\uD83E\uDD10", "\uD83D\uDE36" -> Kind.SHUSH
        "\uD83D\uDE05", "\uD83D\uDE48" -> Kind.SWEAT
        "\uD83D\uDE14", "\uD83E\uDD7A" -> Kind.SAD
        else -> null
    }

    fun supports(e: String): Boolean = kindOf(e) != null

    private fun smooth(x: Float): Float {
        val t = x.coerceIn(0f, 1f)
        return t * t * (3f - 2f * t)
    }

    /** 1 = eyes open, 0 = shut. A quick blink every [period] seconds. */
    private fun blink(now: Float, period: Float = 3.4f, offset: Float = 0f): Float {
        val ph = (now + offset) % period
        val dur = 0.17f
        return if (ph < dur) 1f - sin(PI.toFloat() * ph / dur) else 1f
    }

    private fun oval(c: Canvas, cx: Float, cy: Float, rx: Float, ry: Float, color: Int) {
        p.style = Paint.Style.FILL
        p.color = color
        rect.set(cx - rx, cy - ry, cx + rx, cy + ry)
        c.drawOval(rect, p)
    }

    private fun line(c: Canvas, x1: Float, y1: Float, x2: Float, y2: Float, w: Float, color: Int = DARK) {
        p.style = Paint.Style.STROKE
        p.strokeCap = Paint.Cap.ROUND
        p.strokeWidth = w
        p.color = color
        c.drawLine(x1, y1, x2, y2, p)
    }

    private fun arc(c: Canvas, cx: Float, cy: Float, rx: Float, ry: Float, start: Float, sweep: Float, w: Float, color: Int = DARK) {
        p.style = Paint.Style.STROKE
        p.strokeCap = Paint.Cap.ROUND
        p.strokeWidth = w
        p.color = color
        rect.set(cx - rx, cy - ry, cx + rx, cy + ry)
        c.drawArc(rect, start, sweep, false, p)
    }

    private fun eye(c: Canvas, cx: Float, cy: Float, r: Float, open: Float, lx: Float = 0f, ly: Float = 0f) {
        oval(c, cx + lx * r, cy + ly * r, r * 0.095f, max(r * 0.012f, r * 0.15f * open), DARK)
    }

    private fun star(c: Canvas, cx: Float, cy: Float, ro: Float, color: Int, rot: Float) {
        val ri = ro * 0.45f
        path.reset()
        for (i in 0 until 10) {
            val rr = if (i % 2 == 0) ro else ri
            val a = rot + (-PI.toFloat() / 2f) + i * PI.toFloat() / 5f
            val x = cx + rr * cos(a)
            val y = cy + rr * sin(a)
            if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        path.close()
        p.style = Paint.Style.FILL
        p.color = color
        c.drawPath(path, p)
    }

    private fun heart(c: Canvas, cx: Float, cy: Float, s: Float, color: Int) {
        path.reset()
        path.moveTo(cx, cy + s * 0.9f)
        path.cubicTo(cx - s * 1.6f, cy - s * 0.1f, cx - s * 0.6f, cy - s * 1.2f, cx, cy - s * 0.35f)
        path.cubicTo(cx + s * 0.6f, cy - s * 1.2f, cx + s * 1.6f, cy - s * 0.1f, cx, cy + s * 0.9f)
        path.close()
        p.style = Paint.Style.FILL
        p.color = color
        c.drawPath(path, p)
    }

    private fun smile(c: Canvas, cx: Float, cy: Float, r: Float, wide: Float = 0.38f) {
        arc(c, cx, cy + r * 0.12f, r * wide, r * 0.36f, 20f, 140f, r * 0.075f)
    }

    private fun openMouth(c: Canvas, cx: Float, cy: Float, r: Float, w: Float, h: Float) {
        rect.set(cx - w, cy, cx + w, cy + h)
        p.style = Paint.Style.FILL
        p.color = MOUTH
        c.drawOval(rect, p)
        if (h > r * 0.2f) {
            rect.set(cx - w * 0.6f, cy + h * 0.55f, cx + w * 0.6f, cy + h * 1.0f)
            p.color = TONGUE
            c.drawOval(rect, p)
        }
    }

    private fun base(c: Canvas, cx: Float, cy: Float, r: Float) {
        p.style = Paint.Style.FILL
        p.color = FACE
        c.drawCircle(cx, cy, r, p)
        p.style = Paint.Style.STROKE
        p.strokeWidth = r * 0.06f
        p.color = RIM
        c.drawCircle(cx, cy, r * 0.97f, p)
    }

    private fun zzz(c: Canvas, cx: Float, cy: Float, r: Float, now: Float) {
        p.style = Paint.Style.FILL
        p.typeface = Typeface.DEFAULT_BOLD
        p.textAlign = Paint.Align.CENTER
        for (i in 0 until 3) {
            val ph = ((now * 0.55f) + i / 3f) % 1f
            val a = (sin(PI.toFloat() * ph)).coerceIn(0f, 1f)
            p.color = Color.argb((a * 230).toInt(), 130, 110, 255)
            p.textSize = r * (0.32f + 0.34f * ph)
            c.drawText("Z", cx + r * (0.7f + 0.35f * ph), cy - r * (0.55f + 0.95f * ph), p)
        }
    }

    /**
     * Draws the face for [emoji] centred at ([cx], [cy]) with radius [r].
     * [since] = seconds since the emoji appeared, [now] = a running clock in seconds,
     * [level] = how loud the assistant is speaking (0..1).
     */
    fun draw(c: Canvas, emoji: String, cx: Float, cy: Float, r: Float, since: Float, now: Float, level: Float): Boolean {
        val kind = kindOf(emoji) ?: return false
        c.save()
        when (kind) {
            Kind.SMILE -> {
                c.rotate(sin(now * 1.3f) * 3f, cx, cy)
                base(c, cx, cy, r)
                val o = blink(now)
                eye(c, cx - r * 0.33f, cy - r * 0.15f, r, o)
                eye(c, cx + r * 0.33f, cy - r * 0.15f, r, o)
                smile(c, cx, cy, r, 0.36f + 0.02f * sin(now * 2f))
            }
            Kind.THINK -> {
                c.rotate(sin(now * 1.6f) * 6f, cx, cy)
                base(c, cx, cy, r)
                val lx = 0.35f * cos(now * 0.9f)
                val ly = -0.30f - 0.10f * sin(now * 0.9f)
                eye(c, cx - r * 0.33f, cy - r * 0.12f, r, 1f, lx * 0.5f, ly * 0.4f)
                eye(c, cx + r * 0.33f, cy - r * 0.12f, r, 1f, lx * 0.5f, ly * 0.4f)
                line(c, cx - r * 0.5f, cy - r * 0.42f, cx - r * 0.18f, cy - r * 0.34f, r * 0.07f)
                line(c, cx + r * 0.18f, cy - r * 0.50f - r * 0.05f * sin(now * 2f), cx + r * 0.5f, cy - r * 0.58f - r * 0.05f * sin(now * 2f), r * 0.07f)
                line(c, cx - r * 0.22f + r * 0.06f * sin(now * 1.3f), cy + r * 0.38f, cx + r * 0.22f, cy + r * 0.36f, r * 0.075f)
                p.style = Paint.Style.FILL
                for (i in 0 until 3) {
                    val on = ((now * 1.6f).toInt() % 4) > i
                    p.color = Color.argb(if (on) 230 else 60, 120, 120, 140)
                    c.drawCircle(cx + r * (0.85f + 0.22f * i), cy - r * (0.75f + 0.18f * i), r * (0.07f + 0.03f * i), p)
                }
            }
            Kind.TALK -> {
                c.rotate(sin(now * 2.4f) * 2.5f, cx, cy)
                base(c, cx, cy, r)
                val o = blink(now, 3.9f, 0.7f)
                eye(c, cx - r * 0.33f, cy - r * 0.18f, r, o)
                eye(c, cx + r * 0.33f, cy - r * 0.18f, r, o)
                val h = r * (0.10f + 0.42f * level + 0.10f * abs(sin(now * 9f)))
                openMouth(c, cx, cy + r * 0.18f, r, r * (0.30f + 0.05f * level), h)
            }
            Kind.SLEEP -> {
                c.rotate(sin(now * 0.9f) * 5f, cx, cy)
                base(c, cx, cy, r)
                // Eyes close slowly during the first 1.6 s after the face appears.
                val open = 1f - smooth((since - 0.2f) / 1.4f)
                if (open > 0.12f) {
                    eye(c, cx - r * 0.33f, cy - r * 0.12f, r, open)
                    eye(c, cx + r * 0.33f, cy - r * 0.12f, r, open)
                } else {
                    arc(c, cx - r * 0.33f, cy - r * 0.12f, r * 0.15f, r * 0.10f, 20f, 140f, r * 0.07f)
                    arc(c, cx + r * 0.33f, cy - r * 0.12f, r * 0.15f, r * 0.10f, 20f, 140f, r * 0.07f)
                }
                // A tiny mouth that breathes.
                val m = r * (0.06f + 0.025f * sin(now * 1.8f))
                oval(c, cx, cy + r * 0.40f, m, m * 1.3f, MOUTH)
                if (since > 1.3f) zzz(c, cx, cy, r, now - 1.3f)
            }
            Kind.PARTY -> {
                c.translate(0f, -abs(sin(now * 5f)) * r * 0.10f)
                base(c, cx, cy, r)
                // happy closed eyes
                arc(c, cx - r * 0.33f, cy - r * 0.08f, r * 0.15f, r * 0.13f, 200f, 140f, r * 0.07f)
                arc(c, cx + r * 0.33f, cy - r * 0.08f, r * 0.15f, r * 0.13f, 200f, 140f, r * 0.07f)
                openMouth(c, cx - r * 0.08f, cy + r * 0.20f, r, r * 0.16f, r * 0.20f + r * 0.05f * sin(now * 7f))
                // party horn: grows and curls
                val len = r * (0.35f + 0.30f * (0.5f + 0.5f * sin(now * 7f)))
                p.style = Paint.Style.STROKE
                p.strokeCap = Paint.Cap.ROUND
                p.strokeWidth = r * 0.10f
                p.color = Color.parseColor("#FF5C8A")
                path.reset()
                path.moveTo(cx + r * 0.06f, cy + r * 0.30f)
                path.quadTo(cx + r * 0.06f + len * 0.6f, cy + r * 0.30f - r * 0.05f, cx + r * 0.06f + len, cy + r * 0.22f - len * 0.12f)
                c.drawPath(path, p)
                // hat
                path.reset()
                path.moveTo(cx - r * 0.42f, cy - r * 0.78f)
                path.lineTo(cx + r * 0.42f, cy - r * 0.78f)
                path.lineTo(cx, cy - r * 1.55f)
                path.close()
                p.style = Paint.Style.FILL
                p.color = Color.parseColor("#7C4DFF")
                c.drawPath(path, p)
                p.color = Color.parseColor("#FFD54F")
                c.drawCircle(cx, cy - r * 1.58f, r * 0.10f, p)
                // confetti
                val cols = intArrayOf(Color.parseColor("#FF5252"), Color.parseColor("#40C4FF"), Color.parseColor("#69F0AE"), Color.parseColor("#FFD740"))
                for (i in 0 until 12) {
                    val ph = (now * 0.8f + i * 0.37f) % 1f
                    val x = cx + r * 1.25f * sin(i * 2.3f + 1f)
                    val y = cy - r * 1.3f + ph * r * 2.8f
                    c.save()
                    c.rotate(now * 200f + i * 40f, x, y)
                    p.color = cols[i % 4]
                    rect.set(x - r * 0.06f, y - r * 0.03f, x + r * 0.06f, y + r * 0.03f)
                    c.drawRect(rect, p)
                    c.restore()
                }
            }
            Kind.STARS -> {
                c.translate(0f, -abs(sin(now * 5f)) * r * 0.08f)
                base(c, cx, cy, r)
                val k = 1f + 0.18f * sin(now * 6f)
                star(c, cx - r * 0.34f, cy - r * 0.14f, r * 0.26f * k, Color.parseColor("#FF6F00"), now * 0.8f)
                star(c, cx + r * 0.34f, cy - r * 0.14f, r * 0.26f * k, Color.parseColor("#FF6F00"), -now * 0.8f)
                openMouth(c, cx, cy + r * 0.20f, r, r * 0.26f, r * 0.28f)
                for (i in 0 until 4) {
                    val ph = (now * 0.9f + i * 0.25f) % 1f
                    val a = sin(PI.toFloat() * ph)
                    star(c, cx + r * 1.1f * cos(i * 1.6f + 0.5f), cy + r * 1.0f * sin(i * 2.1f), r * 0.12f * a, Color.parseColor("#FFEB3B"), 0f)
                }
            }
            Kind.SUN -> {
                p.style = Paint.Style.STROKE
                p.strokeCap = Paint.Cap.ROUND
                p.strokeWidth = r * 0.10f
                p.color = Color.parseColor("#FFB300")
                for (i in 0 until 10) {
                    val a = now * 0.8f + i * (2f * PI.toFloat() / 10f)
                    c.drawLine(cx + r * 1.08f * cos(a), cy + r * 1.08f * sin(a), cx + r * 1.34f * cos(a), cy + r * 1.34f * sin(a), p)
                }
                base(c, cx, cy, r)
                val o = blink(now, 3.0f)
                eye(c, cx - r * 0.33f, cy - r * 0.15f, r, o)
                eye(c, cx + r * 0.33f, cy - r * 0.15f, r, o)
                smile(c, cx, cy, r, 0.40f)
            }
            Kind.ROLL -> {
                c.rotate(sin(now * 1.2f) * 4f, cx, cy)
                base(c, cx, cy, r)
                for (sgn in intArrayOf(-1, 1)) {
                    val ex = cx + sgn * r * 0.33f
                    val ey = cy - r * 0.12f
                    oval(c, ex, ey, r * 0.17f, r * 0.21f, Color.WHITE)
                    // the pupil circles around the eye = rolling eyes
                    val a = now * 3.2f
                    oval(c, ex + r * 0.09f * cos(a), ey + r * 0.12f * sin(a), r * 0.075f, r * 0.075f, DARK)
                }
                line(c, cx - r * 0.52f, cy - r * 0.46f, cx - r * 0.16f, cy - r * 0.40f, r * 0.07f)
                line(c, cx + r * 0.16f, cy - r * 0.40f, cx + r * 0.52f, cy - r * 0.46f, r * 0.07f)
                line(c, cx - r * 0.24f, cy + r * 0.40f, cx + r * 0.24f, cy + r * 0.40f, r * 0.075f)
                // a hand that lifts for a "whatever" gesture
                val lift = (0.5f + 0.5f * sin(now * 1.8f))
                val hx = cx + r * 1.0f
                val hy = cy + r * 0.9f - lift * r * 0.7f
                oval(c, hx, hy, r * 0.20f, r * 0.24f, FACE)
                p.style = Paint.Style.STROKE
                p.strokeWidth = r * 0.04f
                p.color = RIM
                rect.set(hx - r * 0.20f, hy - r * 0.24f, hx + r * 0.20f, hy + r * 0.24f)
                c.drawOval(rect, p)
            }
            Kind.LAUGH -> {
                c.rotate(sin(now * 18f) * 4f, cx, cy)
                base(c, cx, cy, r)
                arc(c, cx - r * 0.33f, cy - r * 0.10f, r * 0.16f, r * 0.12f, 200f, 140f, r * 0.08f)
                arc(c, cx + r * 0.33f, cy - r * 0.10f, r * 0.16f, r * 0.12f, 200f, 140f, r * 0.08f)
                openMouth(c, cx, cy + r * 0.14f, r, r * 0.42f, r * (0.38f + 0.08f * abs(sin(now * 12f))))
                // tears fly out of the eyes
                p.style = Paint.Style.FILL
                p.color = DROP
                for (sgn in intArrayOf(-1, 1)) {
                    for (i in 0 until 2) {
                        val ph = (now * 1.4f + i * 0.5f) % 1f
                        c.drawCircle(cx + sgn * (r * 0.50f + ph * r * 0.55f), cy - r * 0.05f + ph * ph * r * 0.7f, r * 0.07f * (1f - ph * 0.5f), p)
                    }
                }
            }
            Kind.LOVE -> {
                c.rotate(sin(now * 1.6f) * 3f, cx, cy)
                base(c, cx, cy, r)
                val k = 0.16f * (1f + 0.22f * sin(now * 6f))
                heart(c, cx - r * 0.33f, cy - r * 0.12f, r * k * 1.5f, Color.parseColor("#F44336"))
                heart(c, cx + r * 0.33f, cy - r * 0.12f, r * k * 1.5f, Color.parseColor("#F44336"))
                smile(c, cx, cy, r, 0.36f)
                val ph = (now * 0.7f) % 1f
                heart(c, cx + r * 0.9f, cy - r * (0.3f + ph * 0.9f), r * 0.12f * sin(PI.toFloat() * ph), Color.parseColor("#FF8A80"))
            }
            Kind.SHUSH -> {
                c.rotate(sin(now * 1.4f) * 3f, cx, cy)
                base(c, cx, cy, r)
                val o = blink(now, 2.6f)
                eye(c, cx - r * 0.33f, cy - r * 0.18f, r, o, 0.25f * sin(now * 1.1f), 0f)
                eye(c, cx + r * 0.33f, cy - r * 0.18f, r, o, 0.25f * sin(now * 1.1f), 0f)
                // finger on the lips
                val bob = r * 0.04f * sin(now * 3f)
                rect.set(cx - r * 0.10f, cy + r * 0.05f + bob, cx + r * 0.10f, cy + r * 0.90f + bob)
                p.style = Paint.Style.FILL
                p.color = FACE
                c.drawRoundRect(rect, r * 0.10f, r * 0.10f, p)
                p.style = Paint.Style.STROKE
                p.strokeWidth = r * 0.04f
                p.color = RIM
                c.drawRoundRect(rect, r * 0.10f, r * 0.10f, p)
            }
            Kind.SWEAT -> {
                base(c, cx, cy, r)
                arc(c, cx - r * 0.33f, cy - r * 0.40f, r * 0.2f, r * 0.08f, 200f, 140f, r * 0.06f)
                eye(c, cx - r * 0.33f, cy - r * 0.12f, r, 1f)
                eye(c, cx + r * 0.33f, cy - r * 0.12f, r, 1f)
                smile(c, cx, cy + r * 0.10f, r, 0.30f)
                val ph = (now * 0.8f) % 1f
                p.style = Paint.Style.FILL
                p.color = DROP
                val dx = cx + r * 0.75f
                val dy = cy - r * 0.55f + ph * r * 0.9f
                path.reset()
                path.moveTo(dx, dy - r * 0.16f)
                path.quadTo(dx + r * 0.14f, dy + r * 0.02f, dx, dy + r * 0.10f)
                path.quadTo(dx - r * 0.14f, dy + r * 0.02f, dx, dy - r * 0.16f)
                c.drawPath(path, p)
            }
            Kind.SAD -> {
                c.translate(0f, sin(now * 1.5f) * r * 0.03f)
                base(c, cx, cy, r)
                val k = 1f + 0.06f * sin(now * 3f)
                oval(c, cx - r * 0.33f, cy - r * 0.10f, r * 0.14f * k, r * 0.19f * k, DARK)
                oval(c, cx + r * 0.33f, cy - r * 0.10f, r * 0.14f * k, r * 0.19f * k, DARK)
                oval(c, cx - r * 0.29f, cy - r * 0.17f, r * 0.05f, r * 0.05f, Color.WHITE)
                oval(c, cx + r * 0.37f, cy - r * 0.17f, r * 0.05f, r * 0.05f, Color.WHITE)
                arc(c, cx, cy + r * 0.62f, r * 0.24f, r * 0.14f, 200f, 140f, r * 0.07f)
                line(c, cx - r * 0.50f, cy - r * 0.40f, cx - r * 0.20f, cy - r * 0.50f, r * 0.06f)
                line(c, cx + r * 0.20f, cy - r * 0.50f, cx + r * 0.50f, cy - r * 0.40f, r * 0.06f)
            }
        }
        c.restore()
        return true
    }
}
