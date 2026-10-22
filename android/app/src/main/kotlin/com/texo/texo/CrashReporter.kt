package com.texo.texo

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.provider.MediaStore
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Writes crash information to Download/texo_logs, so it can be read from
 * Termux (~/storage/downloads/texo_logs) without adb:
 *  - crash_*.txt : an uncaught Kotlin/Java exception
 *  - dart_*.txt  : a Dart error reported by the app
 *  - exit_*.txt  : why the previous run ended (Android 11+), once per exit
 */
object CrashReporter {
    private var installed = false
    private var dartReports = 0

    fun install(context: Context) {
        if (installed) return
        installed = true
        val app = context.applicationContext
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                write(
                    app,
                    "crash_" + stamp() + ".txt",
                    "Uncaught exception in thread " + thread.name + "\n" +
                        android.util.Log.getStackTraceString(error),
                )
            } catch (_: Throwable) {
            }
            previous?.uncaughtException(thread, error)
        }
        Thread {
            try {
                writeExitReasons(app)
            } catch (_: Throwable) {
            }
        }.also { it.isDaemon = true }.start()
    }

    fun dart(context: Context, text: String) {
        if (dartReports >= 20) return
        dartReports++
        try {
            write(context.applicationContext, "dart_" + stamp() + "_" + dartReports + ".txt", text)
        } catch (_: Throwable) {
        }
    }

    private fun stamp(): String =
        SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())

    @android.annotation.SuppressLint("NewApi")
    private fun write(context: Context, name: String, text: String) {
        if (Build.VERSION.SDK_INT < 29) return
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, "text/plain")
            put(MediaStore.Downloads.RELATIVE_PATH, "Download/texo_logs")
        }
        val uri = context.contentResolver.insert(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            values,
        ) ?: return
        context.contentResolver.openOutputStream(uri)?.use { it.write(text.toByteArray()) }
    }

    @android.annotation.SuppressLint("NewApi")
    private fun writeExitReasons(app: Context) {
        if (Build.VERSION.SDK_INT < 30) return
        val am = app.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val list = am.getHistoricalProcessExitReasons(app.packageName, 0, 6)
        if (list.isEmpty()) return
        val prefs = app.getSharedPreferences("texo_crash", Context.MODE_PRIVATE)
        val newest = list[0].timestamp
        if (prefs.getLong("last_exit_ts", 0L) >= newest) return
        prefs.edit().putLong("last_exit_ts", newest).apply()

        val fmt = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US)
        val sb = StringBuilder()
        for (info in list) {
            sb.append(fmt.format(Date(info.timestamp)))
                .append("  ").append(reasonName(info.reason))
                .append("  status=").append(info.status)
                .append("  importance=").append(info.importance)
                .append("  pss=").append(info.pss).append("KB")
                .append("  desc=").append(info.description)
                .append('\n')
            if (info.reason == ApplicationExitInfo.REASON_ANR) {
                try {
                    info.traceInputStream?.bufferedReader()?.use {
                        sb.append(it.readText().take(8000)).append('\n')
                    }
                } catch (_: Throwable) {
                }
            }
        }
        write(app, "exit_" + stamp() + ".txt", sb.toString())
    }

    @android.annotation.SuppressLint("NewApi")
    private fun reasonName(reason: Int): String = when (reason) {
        ApplicationExitInfo.REASON_ANR -> "ANR (app not responding)"
        ApplicationExitInfo.REASON_CRASH -> "CRASH (Java/Kotlin/Dart exception)"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "CRASH_NATIVE (native code)"
        ApplicationExitInfo.REASON_LOW_MEMORY -> "LOW_MEMORY (killed for memory)"
        ApplicationExitInfo.REASON_SIGNALED -> "SIGNALED"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "EXCESSIVE_RESOURCE_USAGE"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "INITIALIZATION_FAILURE"
        ApplicationExitInfo.REASON_USER_REQUESTED -> "USER_REQUESTED"
        ApplicationExitInfo.REASON_USER_STOPPED -> "USER_STOPPED"
        ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "DEPENDENCY_DIED"
        ApplicationExitInfo.REASON_EXIT_SELF -> "EXIT_SELF"
        ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "PERMISSION_CHANGE"
        ApplicationExitInfo.REASON_OTHER -> "OTHER"
        else -> "reason#$reason"
    }
}
