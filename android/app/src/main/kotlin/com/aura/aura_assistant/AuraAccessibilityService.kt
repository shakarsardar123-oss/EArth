package com.aura.aura_assistant

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Build
import android.view.accessibility.AccessibilityEvent

/**
 * AURA AccessibilityService — Phase 6.
 *
 * Provides REAL screen-gesture dispatch (tap / long-press / swipe) via
 * [dispatchGesture]. A static [instance] reference lets [MainActivity]'s
 * `system_control` MethodChannel forward gesture requests here while the
 * service is bound.
 *
 * HONESTY / SAFETY:
 *  - Gesture dispatch requires API 24+ (N). On older releases the caller
 *    (MainActivity) returns `platformUnsupported`.
 *  - When the service is not bound, [instance] is null and the gesture
 *    tool fails closed with `accessibilityDisabled` — it never pretends.
 *  - This service declares NO event-observation capabilities beyond the
 *    minimum needed to be bindable; it does not read or log screen content.
 */
class AuraAccessibilityService : AccessibilityService() {

    companion object {
        /** Non-null only while the service is connected and can dispatch. */
        @Volatile
        var instance: AuraAccessibilityService? = null
            private set
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    // We do not observe events; required override left intentionally empty.
    override fun onAccessibilityEvent(event: AccessibilityEvent?) { /* no-op */ }

    override fun onInterrupt() { /* no-op */ }

    /**
     * Dispatches a gesture and invokes [onDone] with whether the gesture
     * was accepted (dispatched) and whether it completed.
     *
     * Returns false immediately (without calling [onDone]) when the API
     * level does not support gesture dispatch.
     */
    fun performGesture(
        gesture: String,
        x: Double,
        y: Double,
        x2: Double?,
        y2: Double?,
        durationMs: Long,
        onDone: (dispatched: Boolean, completed: Boolean) -> Unit,
    ): Boolean {
        if (Build.VERSION.SDK_INT < 24) return false

        val path = Path()
        val safeDuration = durationMs.coerceIn(10L, 10_000L)

        val stroke: GestureDescription.StrokeDescription = when (gesture) {
            "tap" -> {
                path.moveTo(x.toFloat(), y.toFloat())
                path.lineTo(x.toFloat(), y.toFloat())
                GestureDescription.StrokeDescription(path, 0L, 1L)
            }
            "long_press" -> {
                path.moveTo(x.toFloat(), y.toFloat())
                path.lineTo(x.toFloat(), y.toFloat())
                // A long press is a stationary stroke held for the duration.
                GestureDescription.StrokeDescription(
                    path, 0L, safeDuration.coerceAtLeast(400L)
                )
            }
            "swipe" -> {
                val ex = (x2 ?: x).toFloat()
                val ey = (y2 ?: y).toFloat()
                path.moveTo(x.toFloat(), y.toFloat())
                path.lineTo(ex, ey)
                GestureDescription.StrokeDescription(path, 0L, safeDuration)
            }
            else -> return false
        }

        val description = GestureDescription.Builder().addStroke(stroke).build()

        val callback = object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                onDone(true, true)
            }
            override fun onCancelled(gestureDescription: GestureDescription?) {
                onDone(true, false)
            }
        }

        val accepted = dispatchGesture(description, callback, null)
        if (!accepted) onDone(false, false)
        return accepted
    }
}
