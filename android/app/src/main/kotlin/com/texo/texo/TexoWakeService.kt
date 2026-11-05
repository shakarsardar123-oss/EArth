package com.texo.texo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * Keeps the microphone available while TEXO is in the background or the screen is
 * off. Since Android 11 an app that is not on screen only gets SILENCE from the
 * microphone unless it runs a foreground service of type "microphone": without
 * this service "Hey Texo" could only work while the app was open.
 *
 * It does nothing else: the wake word listener itself lives in TexoAudioBridge.
 */
class TexoWakeService : Service() {

    private var wl: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                nm.createNotificationChannel(
                    NotificationChannel(CH, "TEXO listening", NotificationManager.IMPORTANCE_LOW),
                )
            }
            val open = PendingIntent.getActivity(
                this, 42,
                Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, CH)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }
            val n = b.setSmallIcon(applicationInfo.icon)
                .setContentTitle("TEXO")
                .setContentText("\u0628\u06CE\u0698\u06D5: \u00AB\u0647\u06CE\u06CC \u062A\u06CE\u06A9\u0633\u06C6\u00BB")
                .setOngoing(true)
                .setContentIntent(open)
                .build()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            } else {
                startForeground(ID, n)
            }
            if (wl == null) {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "texo:wake").apply {
                    setReferenceCounted(false)
                    acquire()
                }
            }
            TexoA11yGuard.ensureEnabled(applicationContext)
        } catch (_: Throwable) {
            // Not allowed to start from the background: try again when the app is opened.
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    override fun onDestroy() {
        try {
            wl?.let { if (it.isHeld) it.release() }
        } catch (_: Throwable) {
        }
        wl = null
        super.onDestroy()
    }

    companion object {
        private const val CH = "texo_wake"
        private const val ID = 4108

        fun start(ctx: Context) {
            try {
                val i = Intent(ctx, TexoWakeService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) ctx.startForegroundService(i)
                else ctx.startService(i)
            } catch (_: Throwable) {
            }
        }

        fun stop(ctx: Context) {
            try {
                ctx.stopService(Intent(ctx, TexoWakeService::class.java))
            } catch (_: Throwable) {
            }
        }
    }
}
