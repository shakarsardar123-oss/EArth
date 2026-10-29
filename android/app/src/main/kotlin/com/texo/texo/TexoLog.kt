package com.texo.texo

import android.content.Context
import android.util.Log

/**
 * Diagnostics. Messages go to logcat only.
 *
 * The old version showed a Toast and re-posted two notifications ("TEXO log",
 * "TEXO overlay log") on the main thread for EVERY line, which made the UI
 * and the notification shade laggy. Nothing user-visible is produced now.
 */
object TexoLog {
    private const val TAG = "TEXO"

    fun log(ctx: Context, msg: String) {
        try {
            Log.d(TAG, msg)
        } catch (_: Throwable) {
        }
    }
}
