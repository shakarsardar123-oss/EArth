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
 * Diagnostics: every message is shown as a toast AND kept in a notification
 * ("TEXO log") with the last lines, so it can be read after the toast is gone.
 */
object TexoLog {
    private const val CHANNEL_ID = "texo_diag_log"
    private const val NOTIFICATION_ID = 4299
    private const val KEEP = 40
    private const val SHOWN = 14

    private val main = Handler(Looper.getMainLooper())
    private val lines = ArrayList<String>()
    private val fmt = SimpleDateFormat("HH:mm:ss", Locale.US)

    fun log(ctx: Context, msg: String) {
        val app = ctx.applicationContext
        val text = synchronized(lines) {
            lines.add(fmt.format(Date()) + " " + msg)
            while (lines.size > KEEP) lines.removeAt(0)
            lines.takeLast(SHOWN).joinToString("\n")
        }
        main.post {
            try {
                Toast.makeText(app, msg, Toast.LENGTH_SHORT).show()
            } catch (_: Throwable) {
            }
            try {
                publish(app, text, msg)
            } catch (_: Throwable) {
            }
        }
    }

    private fun publish(app: Context, text: String, last: String) {
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
            .setContentTitle("TEXO log")
            .setContentText(last)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setOnlyAlertOnce(true)
        nm.notify(NOTIFICATION_ID, builder.build())
    }
}
