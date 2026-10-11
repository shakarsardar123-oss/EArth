package com.texo.texo

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Path
import android.graphics.Rect
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Phone-agent actions on top of TexoAccessibilityService.
 * All replies are maps {ok: Boolean, error?: String, ...} (never PlatformException).
 * Kill switch: ACTION_SCREEN_OFF (power button) blocks every action.
 */
object PhoneAgentBridge {

    private const val MAX_NODES = 220

    @Volatile private var killRequested = false
    private var killReceiver: BroadcastReceiver? = null
    private var wakeLock: PowerManager.WakeLock? = null

    fun handle(ctx: Context, call: MethodCall, result: MethodChannel.Result) {
        try {
            result.success(dispatch(ctx, call))
        } catch (t: Throwable) {
            result.success(fail("${t::class.java.simpleName}: ${t.message}"))
        }
    }

    private fun fail(e: String): Map<String, Any?> = mapOf("ok" to false, "error" to e)

    private fun ok(vararg extra: Pair<String, Any?>): Map<String, Any?> {
        val m = HashMap<String, Any?>()
        m["ok"] = true
        for ((k, v) in extra) m[k] = v
        return m
    }

    private fun dispatch(ctx: Context, call: MethodCall): Map<String, Any?> {
        when (call.method) {
            "agentBegin" -> { begin(ctx); return ok() }
            "agentEnd" -> { end(ctx); return ok() }
            "agentKilled" -> return ok("killed" to killRequested)
        }
        if (killRequested) return fail("killed")
        val svc = TexoAccessibilityService.instance ?: return fail("accessibility_off")
        return when (call.method) {
            "a11yRead" -> readScreen(svc)
            "a11yClick" -> click(svc, call)
            "a11yTap" -> {
                val x = call.argument<Number>("x")?.toFloat() ?: return fail("missing_xy")
                val y = call.argument<Number>("y")?.toFloat() ?: return fail("missing_xy")
                if (gesture(svc, x, y, x, y, 60)) ok() else fail("tap_failed")
            }
            "a11yType" -> typeText(svc, call)
            "a11yScroll" -> scroll(svc, call)
            "a11yGlobal" -> global(svc, call)
            "a11yEnter" -> enter(svc)
            "a11yStartIntent" -> startIntent(svc, call)
            else -> fail("unknown_method")
        }
    }

    // ── kill switch ────────────────────────────────────────────────

    private fun begin(ctx: Context) {
        killRequested = false
        val app = ctx.applicationContext
        if (killReceiver == null) {
            val r = object : BroadcastReceiver() {
                override fun onReceive(c: Context?, i: Intent?) {
                    killRequested = true
                    releaseWake()
                }
            }
            app.registerReceiver(r, IntentFilter(Intent.ACTION_SCREEN_OFF))
            killReceiver = r
        }
        if (wakeLock == null) {
            val pm = app.getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wl = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ON_AFTER_RELEASE,
                "texo:agent",
            )
            wl.setReferenceCounted(false)
            wl.acquire()
            wakeLock = wl
        }
    }

    private fun end(ctx: Context) {
        killReceiver?.let {
            try { ctx.applicationContext.unregisterReceiver(it) } catch (_: Throwable) {}
        }
        killReceiver = null
        releaseWake()
    }

    private fun releaseWake() {
        try { wakeLock?.let { if (it.isHeld) it.release() } } catch (_: Throwable) {}
        wakeLock = null
    }

    // ── screen tree ────────────────────────────────────────────────

    private fun walk(n: AccessibilityNodeInfo?, depth: Int, out: MutableList<AccessibilityNodeInfo>) {
        if (n == null || depth > 60 || out.size >= MAX_NODES) return
        if (!n.isVisibleToUser) return
        val interesting = !n.text.isNullOrBlank() ||
            !n.contentDescription.isNullOrBlank() ||
            n.isClickable || n.isEditable || n.isScrollable || n.isCheckable
        if (interesting) out.add(n)
        for (i in 0 until n.childCount) walk(n.getChild(i), depth + 1, out)
    }

    private fun sigOf(n: AccessibilityNodeInfo): String {
        val r = Rect()
        n.getBoundsInScreen(r)
        return "${n.className}|${n.text}|${n.contentDescription}|${r.left},${r.top},${r.right},${r.bottom}"
            .hashCode().toString()
    }

    private fun describe(i: Int, n: AccessibilityNodeInfo): Map<String, Any?> {
        val r = Rect()
        n.getBoundsInScreen(r)
        val pw = n.isPassword
        return mapOf(
            "i" to i,
            "text" to (if (pw) "" else n.text?.toString()?.take(120)),
            "desc" to n.contentDescription?.toString()?.take(120),
            "id" to n.viewIdResourceName?.substringAfterLast('/'),
            "cls" to n.className?.toString()?.substringAfterLast('.'),
            "click" to n.isClickable,
            "edit" to n.isEditable,
            "scroll" to n.isScrollable,
            "checked" to (if (n.isCheckable) n.isChecked else null),
            "pw" to pw,
            "b" to listOf(r.left, r.top, r.right, r.bottom),
            "sig" to sigOf(n),
        )
    }

    private fun readScreen(svc: TexoAccessibilityService): Map<String, Any?> {
        val root = svc.rootInActiveWindow ?: return fail("no_window")
        val list = ArrayList<AccessibilityNodeInfo>()
        walk(root, 0, list)
        return ok(
            "pkg" to root.packageName?.toString(),
            "nodes" to list.mapIndexed { i, n -> describe(i, n) },
        )
    }

    private fun findNode(svc: TexoAccessibilityService, index: Int, sig: String?): AccessibilityNodeInfo? {
        val root = svc.rootInActiveWindow ?: return null
        val list = ArrayList<AccessibilityNodeInfo>()
        walk(root, 0, list)
        val n = list.getOrNull(index) ?: return null
        if (sig != null && sigOf(n) != sig) return null
        return n
    }

    // ── actions ────────────────────────────────────────────────────

    private fun gesture(
        svc: TexoAccessibilityService,
        x1: Float, y1: Float, x2: Float, y2: Float, dur: Long,
    ): Boolean {
        val p = Path()
        p.moveTo(x1, y1)
        if (x1 != x2 || y1 != y2) p.lineTo(x2, y2)
        val g = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(p, 0, dur))
            .build()
        return svc.dispatchGesture(g, null, null)
    }

    private fun click(svc: TexoAccessibilityService, call: MethodCall): Map<String, Any?> {
        val i = call.argument<Number>("i")?.toInt() ?: return fail("missing_i")
        val n = findNode(svc, i, call.argument<String>("sig")) ?: return fail("stale_node")
        val long = call.argument<Boolean>("long") ?: false
        val r = Rect()
        n.getBoundsInScreen(r)
        var t: AccessibilityNodeInfo? = n
        while (t != null) {
            val can = if (long) t.isLongClickable else t.isClickable
            if (can) {
                val done = t.performAction(
                    if (long) AccessibilityNodeInfo.ACTION_LONG_CLICK
                    else AccessibilityNodeInfo.ACTION_CLICK,
                )
                if (done) return ok("via" to "node")
                break
            }
            t = t.parent
        }
        val cx = r.centerX().toFloat()
        val cy = r.centerY().toFloat()
        return if (gesture(svc, cx, cy, cx, cy, if (long) 700L else 60L)) ok("via" to "gesture")
        else fail("click_failed")
    }

    private fun typeText(svc: TexoAccessibilityService, call: MethodCall): Map<String, Any?> {
        val text = call.argument<String>("text") ?: return fail("missing_text")
        val i = call.argument<Number>("i")?.toInt() ?: -1
        val allowPw = call.argument<Boolean>("allowPassword") ?: false
        val append = call.argument<Boolean>("append") ?: false
        val n: AccessibilityNodeInfo = (
            if (i >= 0) findNode(svc, i, call.argument<String>("sig"))
            else svc.rootInActiveWindow?.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            ) ?: return fail(if (i >= 0) "stale_node" else "no_focused_input")
        if (n.isPassword && !allowPw) return fail("password_field_needs_consent")
        n.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
        val base = if (append) (n.text?.toString() ?: "") else ""
        val b = Bundle()
        b.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, base + text)
        return if (n.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, b)) ok() else fail("set_text_failed")
    }

    private fun scroll(svc: TexoAccessibilityService, call: MethodCall): Map<String, Any?> {
        val dir = call.argument<String>("dir") ?: "down"
        val root = svc.rootInActiveWindow ?: return fail("no_window")
        val list = ArrayList<AccessibilityNodeInfo>()
        walk(root, 0, list)
        var best: AccessibilityNodeInfo? = null
        var bestArea = -1
        for (n in list) {
            if (!n.isScrollable) continue
            val r = Rect()
            n.getBoundsInScreen(r)
            val area = r.width() * r.height()
            if (area > bestArea) { bestArea = area; best = n }
        }
        val forward = dir == "down" || dir == "right"
        val node = best
        if (node != null) {
            val act = if (forward) AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
            else AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
            if (node.performAction(act)) return ok("via" to "node")
        }
        val dm = svc.resources.displayMetrics
        val w = dm.widthPixels.toFloat()
        val h = dm.heightPixels.toFloat()
        val scrolled = when (dir) {
            "down" -> gesture(svc, w * 0.5f, h * 0.7f, w * 0.5f, h * 0.3f, 350)
            "up" -> gesture(svc, w * 0.5f, h * 0.3f, w * 0.5f, h * 0.7f, 350)
            "right" -> gesture(svc, w * 0.8f, h * 0.5f, w * 0.2f, h * 0.5f, 350)
            else -> gesture(svc, w * 0.2f, h * 0.5f, w * 0.8f, h * 0.5f, 350)
        }
        return if (scrolled) ok("via" to "gesture") else fail("scroll_failed")
    }

    private fun global(svc: TexoAccessibilityService, call: MethodCall): Map<String, Any?> {
        val a = when (call.argument<String>("name")) {
            "back" -> AccessibilityService.GLOBAL_ACTION_BACK
            "home" -> AccessibilityService.GLOBAL_ACTION_HOME
            "recents" -> AccessibilityService.GLOBAL_ACTION_RECENTS
            "notifications" -> AccessibilityService.GLOBAL_ACTION_NOTIFICATIONS
            "quick_settings" -> AccessibilityService.GLOBAL_ACTION_QUICK_SETTINGS
            else -> return fail("bad_global_action")
        }
        return if (svc.performGlobalAction(a)) ok() else fail("global_failed")
    }

    private fun enter(svc: TexoAccessibilityService): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < 30) return fail("enter_unsupported_tap_search_key_instead")
        val n = svc.rootInActiveWindow?.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            ?: return fail("no_focused_input")
        val id = AccessibilityNodeInfo.AccessibilityAction.ACTION_IME_ENTER.id
        return if (n.performAction(id)) ok() else fail("enter_failed")
    }

    private fun startIntent(svc: TexoAccessibilityService, call: MethodCall): Map<String, Any?> {
        val action = call.argument<String>("action") ?: Intent.ACTION_VIEW
        val data = call.argument<String>("data")
        val pkg = call.argument<String>("package")
        val type = call.argument<String>("type")
        val extras = call.argument<Map<String, Any?>>("extras")
        val i = Intent(action)
        if (data != null && type != null) i.setDataAndType(Uri.parse(data), type)
        else if (data != null) i.data = Uri.parse(data)
        else if (type != null) i.type = type
        if (!pkg.isNullOrBlank()) i.setPackage(pkg)
        extras?.forEach { (k, v) ->
            when (v) {
                is String -> i.putExtra(k, v)
                is Boolean -> i.putExtra(k, v)
                is Int -> i.putExtra(k, v)
                is Long -> i.putExtra(k, v)
                is Double -> i.putExtra(k, v)
                else -> Unit
            }
        }
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            svc.startActivity(i)
            ok()
        } catch (e: ActivityNotFoundException) {
            fail("no_activity_for_intent")
        }
    }
}
