package com.texo.texo

import android.content.Context
import android.content.pm.PackageManager
import android.provider.Settings

/**
 * Switches the accessibility service back on whenever Android (or the phone's
 * battery manager) has turned it off.
 *
 * Writing that setting needs the WRITE_SECURE_SETTINGS permission, which an app
 * cannot give itself: it is granted once from outside (Shizuku / adb):
 *     pm grant com.texo.texo android.permission.WRITE_SECURE_SETTINGS
 * Without it this class does nothing.
 */
object TexoA11yGuard {
    private const val FLAT = "com.texo.texo/com.texo.texo.TexoAccessibilityService"

    fun canWrite(ctx: Context): Boolean =
        ctx.checkSelfPermission("android.permission.WRITE_SECURE_SETTINGS") ==
            PackageManager.PERMISSION_GRANTED

    fun isEnabled(ctx: Context): Boolean {
        val v = Settings.Secure.getString(
            ctx.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        return v.split(':').any { it.contains("TexoAccessibilityService", ignoreCase = true) }
    }

    /** True when the service is (now) enabled. */
    fun ensureEnabled(ctx: Context): Boolean {
        try {
            if (isEnabled(ctx)) return true
            if (!canWrite(ctx)) return false
            val cr = ctx.contentResolver
            val cur = Settings.Secure.getString(cr, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
            val next = if (cur.isBlank()) FLAT else "$cur:$FLAT"
            Settings.Secure.putString(cr, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES, next)
            Settings.Secure.putInt(cr, Settings.Secure.ACCESSIBILITY_ENABLED, 1)
            return true
        } catch (_: Throwable) {
            return false
        }
    }
}
