package com.texo.texo

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.os.Build
import android.view.Display
import android.view.WindowManager

/**
 * Asks Android for the highest refresh rate this screen supports (60, 90, 120,
 * 144 Hz ...) at its current resolution. Every phone gets its own best value;
 * a 60 Hz phone simply stays at 60 Hz.
 */
object TexoDisplay {

    @Suppress("DEPRECATION")
    @SuppressLint("NewApi")
    private fun bestMode(context: Context): Display.Mode? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
        return try {
            val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val display = wm.defaultDisplay
            val current = display.mode
            var best = current
            for (m in display.supportedModes) {
                if (m.physicalWidth == current.physicalWidth &&
                    m.physicalHeight == current.physicalHeight &&
                    m.refreshRate > best.refreshRate
                ) {
                    best = m
                }
            }
            best
        } catch (_: Throwable) {
            null
        }
    }

    /** For overlay windows (pill, caption, flash). */
    @SuppressLint("NewApi")
    fun apply(lp: WindowManager.LayoutParams, context: Context) {
        val m = bestMode(context) ?: return
        try {
            lp.preferredDisplayModeId = m.modeId
            lp.preferredRefreshRate = m.refreshRate
        } catch (_: Throwable) {
        }
    }

    /** For the app window itself (call from onResume). */
    @SuppressLint("NewApi")
    fun requestBestRefreshRate(activity: Activity) {
        val m = bestMode(activity) ?: return
        try {
            val lp = activity.window.attributes
            lp.preferredDisplayModeId = m.modeId
            lp.preferredRefreshRate = m.refreshRate
            activity.window.attributes = lp
        } catch (_: Throwable) {
        }
    }
}
