package com.aura.aura_assistant

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngineCache

/**
 * BroadcastReceiver that handles BOOT_COMPLETED to reschedule
 * pending alarms after device restart.
 *
 * When the device boots, this receiver triggers the Flutter engine
 * (if running) to reschedule all saved alarms via the alarm service.
 * If the engine isn't running yet, alarms will be rescheduled
 * when the app is next opened (via the pending_alarm_id bridge
 * in main.dart).
 */
class AlarmBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.MY_PACKAGE_REPLACED",
            "android.intent.action.QUICKBOOT_POWERON" -> {
                // Signal to the Flutter side that a boot occurred.
                // The Flutter AlarmNotificationService will reschedule
                // alarms when the app initializes.
                val prefs = context.getSharedPreferences(
                    "aura_alarm_prefs",
                    Context.MODE_PRIVATE
                )
                prefs.edit()
                    .putBoolean("needs_alarm_reschedule", true)
                    .apply()
            }
        }
    }
}