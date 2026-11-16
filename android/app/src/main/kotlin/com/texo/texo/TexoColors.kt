package com.texo.texo

import android.graphics.Color
import kotlin.math.pow

/** Pure colour helpers: Kurdish/English colour names and readable-contrast checks. */
object TexoColors {
    private val names: List<Pair<String, Int>> = listOf(
        "ئاسمانی" to Color.parseColor("#38BDF8"), "sky" to Color.parseColor("#38BDF8"),
        "خۆڵەمێشی" to Color.parseColor("#8A8FA8"), "gray" to Color.parseColor("#8A8FA8"), "grey" to Color.parseColor("#8A8FA8"),
        "پرتەقاڵی" to Color.parseColor("#FF9F43"), "orange" to Color.parseColor("#FF9F43"),
        "پەمەیی" to Color.parseColor("#F472B6"), "pink" to Color.parseColor("#F472B6"),
        "قاوەیی" to Color.parseColor("#8B5A2B"), "brown" to Color.parseColor("#8B5A2B"),
        "مۆر" to Color.parseColor("#A78BFA"), "purple" to Color.parseColor("#A78BFA"),
        "سەوز" to Color.parseColor("#34D399"), "green" to Color.parseColor("#34D399"),
        "زەرد" to Color.parseColor("#FACC15"), "yellow" to Color.parseColor("#FACC15"),
        "سوور" to Color.parseColor("#EF4444"), "red" to Color.parseColor("#EF4444"),
        "شین" to Color.parseColor("#3B82F6"), "blue" to Color.parseColor("#3B82F6"),
        "سپی" to Color.WHITE, "white" to Color.WHITE,
        "ڕەش" to Color.BLACK, "رەش" to Color.BLACK, "black" to Color.BLACK,
    )

    private fun norm(s: String): String = s.lowercase()
        .replace('ك', 'ک').replace('ي', 'ی').replace('ى', 'ی').replace('ھ', 'ه')

    /** First colour name found in [text], or null. */
    fun parse(text: String): Int? {
        val t = norm(text)
        for ((n, c) in names) if (t.contains(norm(n))) return c
        return null
    }

    private fun lin(v: Int): Double {
        val c = v / 255.0
        return if (c <= 0.03928) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
    }

    fun luminance(color: Int): Double =
        0.2126 * lin(Color.red(color)) + 0.7152 * lin(Color.green(color)) + 0.0722 * lin(Color.blue(color))

    fun contrast(a: Int, b: Int): Double {
        val la = luminance(a)
        val lb = luminance(b)
        return (maxOf(la, lb) + 0.05) / (minOf(la, lb) + 0.05)
    }

    /** [fg] if it is readable on [bg] (ratio >= 4.5), else black or white, whichever contrasts more. */
    fun readable(fg: Int, bg: Int): Int {
        if (contrast(fg, bg) >= 4.5) return fg
        return if (contrast(Color.WHITE, bg) >= contrast(Color.BLACK, bg)) Color.WHITE else Color.BLACK
    }
}
