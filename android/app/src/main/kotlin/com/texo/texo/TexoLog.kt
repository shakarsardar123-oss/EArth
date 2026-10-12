package com.texo.texo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Diagnostics: every message is a toast, and is kept in a notification
 * ("TEXO log"). Overlay-related lines also go to a separate notification
 * ("TEXO overlay log") so they do not scroll away behind STT lines.
 */
object TexoLog {
    private const val CHANNEL_ID = "texo_diag_log"
    private const val MAIN_ID = 4299
    private const val OVERLAY_ID = 4298
    private const val KEEP = 40
    private const val SHOWN = 14

    private val main = Handler(Looper.getMainLooper())
    private val lines = ArrayList<String>()
    private val overlayLines = ArrayList<String>()
    private val fmt = SimpleDateFormat("HH:mm:ss", Locale.US)
    private val overlayWords =
        listOf("overlay", "service", "foreground", "addview", "hide", "bridge", "fallback")

    fun log(ctx: Context, msg: String) {
        val app = ctx.applicationContext
        val low = msg.lowercase(Locale.ROOT)
        val isOverlay = overlayWords.any { low.contains(it) }
        val texts = synchronized(lines) {
            val stamped = fmt.format(Date()) + " " + msg
            lines.add(stamped)
            while (lines.size > KEEP) lines.removeAt(0)
            var ov: String? = null
            if (isOverlay) {
                overlayLines.add(stamped)
                while (overlayLines.size > KEEP) overlayLines.removeAt(0)
                ov = overlayLines.takeLast(SHOWN).joinToString("\n")
            }
            Pair(lines.takeLast(SHOWN).joinToString("\n"), ov)
        }
        main.post {
            try {
                Toast.makeText(app, msg, Toast.LENGTH_SHORT).show()
            } catch (_: Throwable) {
            }
            try {
                publish(app, MAIN_ID, "TEXO log", texts.first, msg)
            } catch (_: Throwable) {
            }
            val ov = texts.second
            if (ov != null) {
                try {
                    publish(app, OVERLAY_ID, "TEXO overlay log", ov, msg)
                } catch (_: Throwable) {
                }
            }
        }
    }

    private fun publish(app: Context, id: Int, title: String, text: String, last: String) {
        val nm = app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                nm.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID,
                        "TEXO diagnostics",
                        NotificationManager.IMPORTANCE_LOW,
                    ),
                )
                Notification.Builder(app, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(app)
            }
        builder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(last)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setOnlyAlertOnce(true)
        nm.notify(id, builder.build())
    }
}
