package com.aura.aura_assistant

import android.Manifest
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.ActivityManager
import android.app.AlarmManager
import android.app.role.RoleManager
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall

/**
 * AURA MainActivity — unified native MethodChannel handler.
 *
 * Handles ALL platform channels used by the AURA Flutter app:
 *   1. com.aura.assistant/central_permissions  — Central permission check/request/openSettings
 *   2. com.aura.device/permissions             — Special permission check/request (overlay, accessibility, assistant, screenCapture, batteryOptimization, exactAlarm)
 *   3. com.aura.assistant/assistant_integration — Assistant role check/request/openSettings/invocation
 *   4. com.aura.aura_assistant/device           — Device info, battery, network, launch app, settings, URL
 *
 * P2/P3 FIX: All previously empty channels now have working handlers.
 * P3 FIX: ASSIST intent filter data is captured and forwarded to Flutter.
 */
class MainActivity : FlutterActivity() {

    // ─── Channel names (must match Flutter side exactly) ──────────
    private val centralPermChannel   = "com.aura.assistant/central_permissions"
    private val devicePermChannel    = "com.aura.device/permissions"
    private val assistantChannel     = "com.aura.assistant/assistant_integration"
    private val deviceChannel        = "com.aura.aura_assistant/device"
    // Phase 6: separate additive channel for system-control capabilities.
    private val systemControlChannel = "com.aura.aura_assistant/system_control"

    // Final Voice Phase: native real-audio bridge (own channels registered internally).
    private var audioBridge: AuraAudioBridge? = null

    // ─── Lifecycle ───────────────────────────────────────────────

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Central permissions channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, centralPermChannel)
            .setMethodCallHandler(::handleCentralPermissions)

        // Device/special permissions channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, devicePermChannel)
            .setMethodCallHandler(::handleDevicePermissions)

        // Assistant integration channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, assistantChannel)
            .setMethodCallHandler(::handleAssistantIntegration)

        // Device actions channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannel)
            .setMethodCallHandler(::handleDeviceActions)

        // Phase 6: system-control channel (bluetooth/wifi/memory/gesture/panels)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, systemControlChannel)
            .setMethodCallHandler(::handleSystemControl)

        // Final Voice Phase: real audio pipeline (output-level Visualizer,
        // echo-safe mic + AEC/VAD, acoustic wake-word scaffold). Registers its
        // own Method/Event channels on the same messenger.
        audioBridge = AuraAudioBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger)

        // Floating overlay channel (own file — see FloatingAuraBridge.kt).
        FloatingAuraBridge.attach(this, flutterEngine)
    }

    override fun onDestroy() {
        // Release native audio resources (Visualizer / AudioRecord / AEC).
        try { audioBridge?.dispose() } catch (_: Throwable) {}
        FloatingAuraBridge.detach(this)
        audioBridge = null
        super.onDestroy()
    }

    // ═══════════════════════════════════════════════════════════════
    // 1.  CENTRAL PERMISSIONS CHANNEL
    //     com.aura.assistant/central_permissions
    // ═══════════════════════════════════════════════════════════════

    private fun handleCentralPermissions(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkStatus" -> {
                val perm = call.argument<String>("permission") ?: run {
                    result.error("INVALID_ARGS", "Missing 'permission' argument", null)
                    return
                }
                val status = checkPermissionStatus(perm)
                result.success(mapOf("status" to status))
            }
            "requestPermission" -> {
                val perm = call.argument<String>("permission") ?: run {
                    result.error("INVALID_ARGS", "Missing 'permission' argument", null)
                    return
                }
                // For special permissions, delegate to platform-specific request
                val isSpecial = perm in listOf("accessibility", "overlay", "screenCapture", "assistant", "batteryOptimization", "exactAlarm")
                if (isSpecial) {
                    requestSpecialPermission(perm)
                    val status = checkPermissionStatus(perm)
                    result.success(mapOf("status" to status, "isGranted" to (status == "granted")))
                } else {
                    // For runtime permissions, we can't request from here without
                    // Activity-level requestPermissions. The permission_handler plugin
                    // handles those on the Flutter side. Return current status.
                    val status = checkPermissionStatus(perm)
                    result.success(mapOf("status" to status, "isGranted" to (status == "granted")))
                }
            }
            "shouldShowRationale" -> {
                val perm = call.argument<String>("permission") ?: run {
                    result.error("INVALID_ARGS", "Missing 'permission' argument", null)
                    return
                }
                // shouldShowRequestPermissionRationale only applies to runtime perms
                val isRuntime = perm in listOf("microphone", "camera", "notification", "storage", "location")
                val show = if (isRuntime) {
                    @Suppress("DEPRECATION")
                    shouldShowRequestPermissionRationale(permToManifest(perm))
                } else false
                result.success(mapOf("show" to show))
            }
            "openSettings" -> {
                val perm = call.argument<String>("permission") ?: ""
                openPermissionSettings(perm)
                result.success(mapOf("success" to true))
            }
            "checkAll" -> {
                val perms = call.argument<List<String>>("permissions") ?: emptyList()
                val statuses = mutableMapOf<String, String>()
                for (p in perms) {
                    statuses[p] = checkPermissionStatus(p)
                }
                result.success(mapOf("statuses" to statuses))
            }
            else -> result.notImplemented()
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // 2.  DEVICE / SPECIAL PERMISSIONS CHANNEL
    //     com.aura.device/permissions
    // ═══════════════════════════════════════════════════════════════

    private fun handleDevicePermissions(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkPermission" -> {
                val perm = call.argument<String>("permission") ?: run {
                    result.error("INVALID_ARGS", "Missing 'permission' argument", null)
                    return
                }
                val granted = isSpecialPermissionGranted(perm)
                result.success(granted)
            }
            "requestPermission" -> {
                val perm = call.argument<String>("permission") ?: run {
                    result.error("INVALID_ARGS", "Missing 'permission' argument", null)
                    return
                }
                requestSpecialPermission(perm)
                // After requesting, return the *current* status — user may or may not have granted
                val granted = isSpecialPermissionGranted(perm)
                result.success(granted)
            }
            else -> result.notImplemented()
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // 3.  ASSISTANT INTEGRATION CHANNEL
    //     com.aura.assistant/assistant_integration
    // ═══════════════════════════════════════════════════════════════

    private fun handleAssistantIntegration(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkIsDefaultAssistant" -> {
                result.success(isAuraDefaultAssistant())
            }
            "getAssistantAvailability" -> {
                result.success(getAssistantAvailability())
            }
            "openAssistantSettings" -> {
                // Never fake success: if no settings screen can be resolved we
                // surface a real error to Flutter instead of pretending it worked.
                try {
                    val route = openAssistantRoleSettings()
                    result.success(mapOf("launched" to true, "route" to route))
                } catch (e: Exception) {
                    result.error("OPEN_SETTINGS_FAILED", e.message, null)
                }
            }
            "isAssistantRoleAvailable" -> {
                result.success(isAssistantRoleAvailable())
            }
            "getInvocationData" -> {
                result.success(getInvocationDataFromIntent())
            }
            "getAndroidApiLevel" -> {
                result.success(Build.VERSION.SDK_INT)
            }
            else -> result.notImplemented()
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // 4.  DEVICE ACTIONS CHANNEL
    //     com.aura.aura_assistant/device
    // ═══════════════════════════════════════════════════════════════

    private fun handleDeviceActions(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getDeviceInfo" -> {
                result.success(mapOf(
                    "brand" to Build.BRAND,
                    "model" to Build.MODEL,
                    "manufacturer" to Build.MANUFACTURER,
                    "androidVersion" to Build.VERSION.RELEASE,
                    "sdkInt" to Build.VERSION.SDK_INT,
                    "device" to Build.DEVICE,
                    "isPhysicalDevice" to !(Build.FINGERPRINT.contains("generic", ignoreCase = true)
                            || Build.FINGERPRINT.contains("emulator", ignoreCase = true)),
                    "board" to Build.BOARD,
                    "hardware" to Build.HARDWARE
                ))
            }
            "getBatteryInfo" -> {
                try {
                    val bm = getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
                    val level = bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)
                    val charging = bm.isCharging
                    result.success(mapOf(
                        "level" to level,
                        "isCharging" to charging,
                        "chargingType" to "unknown" // detailed charging type requires sticky intent
                    ))
                } catch (e: Exception) {
                    result.error("BATTERY_ERROR", e.message, null)
                }
            }
            "getNetworkInfo" -> {
                try {
                    val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
                    val activeNet = cm.activeNetworkInfo
                    val isConnected = activeNet?.isConnectedOrConnecting == true
                    val type = when (activeNet?.type) {
                        android.net.ConnectivityManager.TYPE_WIFI -> "wifi"
                        android.net.ConnectivityManager.TYPE_MOBILE -> "mobile"
                        android.net.ConnectivityManager.TYPE_ETHERNET -> "ethernet"
                        else -> if (isConnected) "unknown" else "none"
                    }
                    result.success(mapOf(
                        "isConnected" to isConnected,
                        "type" to type,
                        "networkName" to null // network name not easily accessible on modern Android
                    ))
                } catch (e: Exception) {
                    result.error("NETWORK_ERROR", e.message, null)
                }
            }
            "launchApp" -> {
                val packageId = call.argument<String>("packageId") ?: run {
                    result.error("INVALID_ARGS", "Missing 'packageId'", null)
                    return
                }
                try {
                    val intent = packageManager.getLaunchIntentForPackage(packageId)
                    if (intent != null) {
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(mapOf("launched" to true))
                    } else {
                        result.error("appNotFound", "App $packageId not found", null)
                    }
                } catch (e: Exception) {
                    result.error("launchFailed", e.message, null)
                }
            }
            "openSystemSettings" -> {
                val action = call.argument<String>("action") ?: run {
                    result.error("INVALID_ARGS", "Missing 'action'", null)
                    return
                }
                try {
                    val intent = Intent(mapSettingsAction(action)).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(mapOf("launched" to true))
                } catch (e: Exception) {
                    result.error("launchFailed", e.message, null)
                }
            }
            "launchUrl" -> {
                val url = call.argument<String>("url") ?: run {
                    result.error("INVALID_ARGS", "Missing 'url'", null)
                    return
                }
                try {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(mapOf("launched" to true))
                } catch (e: Exception) {
                    result.error("launchFailed", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // 5.  SYSTEM CONTROL CHANNEL  (Phase 6)
    //     com.aura.aura_assistant/system_control
    // ═══════════════════════════════════════════════════════════════

    private fun handleSystemControl(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getBluetoothState" -> handleGetBluetoothState(result)
            "setBluetoothEnabled" -> handleSetBluetoothEnabled(call, result)
            "getWifiState" -> handleGetWifiState(result)
            "setWifiEnabled" -> handleSetWifiEnabled(call, result)
            "getMemoryInfo" -> result.success(readMemoryInfo())
            "optimizeResources" -> handleOptimizeResources(result)
            "isAccessibilityServiceEnabled" ->
                result.success(mapOf("enabled" to isAuraAccessibilityBound()))
            "dispatchGesture" -> handleDispatchGesture(call, result)
            "openSettingsPanel" -> handleOpenSettingsPanel(call, result)
            else -> result.notImplemented()
        }
    }

    // ── Bluetooth ───────────────────────────────────────────────────

    private fun bluetoothAdapter(): BluetoothAdapter? {
        return if (Build.VERSION.SDK_INT >= 18) {
            val bm = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            bm?.adapter
        } else {
            @Suppress("DEPRECATION")
            BluetoothAdapter.getDefaultAdapter()
        }
    }

    private fun handleGetBluetoothState(result: MethodChannel.Result) {
        val adapter = bluetoothAdapter()
        if (adapter == null) {
            result.success(mapOf("supported" to false, "enabled" to false))
            return
        }
        val enabled = try { adapter.isEnabled } catch (e: SecurityException) { false }
        result.success(mapOf("supported" to true, "enabled" to enabled))
    }

    private fun handleSetBluetoothEnabled(call: MethodCall, result: MethodChannel.Result) {
        val enable = call.argument<Boolean>("enable") ?: run {
            result.error("INVALID_ARGS", "Missing 'enable'", null); return
        }
        val adapter = bluetoothAdapter()
        if (adapter == null) {
            result.error("unsupported", "Bluetooth not supported on this device", null)
            return
        }
        // API 33+: enable()/disable() are removed/no-op. Route via settings panel.
        if (Build.VERSION.SDK_INT >= 33) {
            openPanelOrSettings("bluetooth")
            result.success(mapOf(
                "requested" to enable,
                "enabled" to (try { adapter.isEnabled } catch (e: SecurityException) { false }),
                "method" to "settings_panel",
                "requiresUserAction" to true
            ))
            return
        }
        // API < 33: attempt a direct toggle (needs BLUETOOTH_ADMIN).
        try {
            @Suppress("DEPRECATION")
            val ok = if (enable) adapter.enable() else adapter.disable()
            // enable()/disable() are async; report the CURRENT verified state
            // plus whether the request was accepted. We never claim the final
            // state changed if the OS rejected the call.
            result.success(mapOf(
                "requested" to enable,
                "enabled" to (try { adapter.isEnabled } catch (e: SecurityException) { false }),
                "accepted" to ok,
                "method" to "direct",
                "requiresUserAction" to false
            ))
        } catch (e: SecurityException) {
            openPanelOrSettings("bluetooth")
            result.success(mapOf(
                "requested" to enable,
                "enabled" to false,
                "method" to "settings_panel",
                "requiresUserAction" to true,
                "note" to "BLUETOOTH_ADMIN not granted; opened settings"
            ))
        }
    }

    // ── Wi-Fi ──────────────────────────────────────────────────────

    private fun wifiManager(): WifiManager? =
        applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager

    private fun handleGetWifiState(result: MethodChannel.Result) {
        val wm = wifiManager()
        if (wm == null) {
            result.success(mapOf("enabled" to false, "ssid" to null))
            return
        }
        val enabled = try { wm.isWifiEnabled } catch (e: SecurityException) { false }
        result.success(mapOf("enabled" to enabled, "ssid" to null))
    }

    private fun handleSetWifiEnabled(call: MethodCall, result: MethodChannel.Result) {
        val enable = call.argument<Boolean>("enable") ?: run {
            result.error("INVALID_ARGS", "Missing 'enable'", null); return
        }
        val wm = wifiManager()
        if (wm == null) {
            result.error("unsupported", "Wi-Fi not supported", null); return
        }
        // API 29+: setWifiEnabled is a hard no-op by policy. Open the panel.
        if (Build.VERSION.SDK_INT >= 29) {
            openPanelOrSettings("wifi")
            result.success(mapOf(
                "requested" to enable,
                "enabled" to (try { wm.isWifiEnabled } catch (e: Exception) { false }),
                "method" to "settings_panel",
                "requiresUserAction" to true
            ))
            return
        }
        try {
            @Suppress("DEPRECATION")
            val ok = wm.setWifiEnabled(enable)
            result.success(mapOf(
                "requested" to enable,
                "enabled" to (try { wm.isWifiEnabled } catch (e: Exception) { false }),
                "accepted" to ok,
                "method" to "direct",
                "requiresUserAction" to false
            ))
        } catch (e: Exception) {
            openPanelOrSettings("wifi")
            result.success(mapOf(
                "requested" to enable,
                "enabled" to false,
                "method" to "settings_panel",
                "requiresUserAction" to true
            ))
        }
    }

    // ── Memory / resource optimization ───────────────────────────────

    private fun readMemoryInfo(): Map<String, Any> {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val mi = ActivityManager.MemoryInfo()
        am.getMemoryInfo(mi)
        val runtime = Runtime.getRuntime()
        val javaUsed = runtime.totalMemory() - runtime.freeMemory()
        val nativeUsed = try { android.os.Debug.getNativeHeapAllocatedSize() } catch (e: Exception) { 0L }
        return mapOf(
            "totalMem" to mi.totalMem,
            "availMem" to mi.availMem,
            "lowMemory" to mi.lowMemory,
            "threshold" to mi.threshold,
            "appJavaHeapUsedBytes" to javaUsed,
            "appNativeHeapUsedBytes" to nativeUsed
        )
    }

    private fun handleOptimizeResources(result: MethodChannel.Result) {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val before = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
        val actions = mutableListOf<String>()

        // 1. Release this app's own caches / hint the VM to collect.
        try {
            System.gc()
            System.runFinalization()
            System.gc()
            actions.add("gc")
        } catch (e: Exception) { /* non-fatal */ }

        // 2. If we hold KILL_BACKGROUND_PROCESSES, ask the OS to trim other
        //    apps' background processes. Never assume the permission is held.
        var killedBackground = false
        val hasKill = checkSelfPermission(Manifest.permission.KILL_BACKGROUND_PROCESSES) ==
            PackageManager.PERMISSION_GRANTED
        if (hasKill) {
            try {
                val pm = packageManager
                val pkgs = pm.getInstalledApplications(0)
                for (app in pkgs) {
                    if (app.packageName == packageName) continue
                    try { am.killBackgroundProcesses(app.packageName) } catch (e: Exception) { }
                }
                killedBackground = true
                actions.add("killBackgroundProcesses")
            } catch (e: Exception) { /* non-fatal */ }
        }

        // Give the OS a brief moment, then re-measure for a VERIFIED delta.
        Handler(Looper.getMainLooper()).postDelayed({
            val after = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
            result.success(mapOf(
                "beforeAvailMem" to before.availMem,
                "afterAvailMem" to after.availMem,
                "freedBytes" to (after.availMem - before.availMem),
                "killedBackground" to killedBackground,
                "actions" to actions
            ))
        }, 300)
    }

    // ── Accessibility gesture ───────────────────────────────────────

    private fun isAuraAccessibilityBound(): Boolean {
        // Bound AND enabled: the running instance is the source of truth.
        return AuraAccessibilityService.instance != null && isAccessibilityEnabled()
    }

    private fun handleDispatchGesture(call: MethodCall, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 24) {
            result.error("platformUnsupported", "Gesture dispatch requires API 24+", null)
            return
        }
        val service = AuraAccessibilityService.instance
        if (service == null || !isAccessibilityEnabled()) {
            result.error("accessibilityDisabled", "Accessibility service not bound", null)
            return
        }
        val gesture = call.argument<String>("gesture") ?: run {
            result.error("INVALID_ARGS", "Missing 'gesture'", null); return
        }
        val x = (call.argument<Number>("x"))?.toDouble() ?: run {
            result.error("INVALID_ARGS", "Missing 'x'", null); return
        }
        val y = (call.argument<Number>("y"))?.toDouble() ?: run {
            result.error("INVALID_ARGS", "Missing 'y'", null); return
        }
        val x2 = (call.argument<Number>("x2"))?.toDouble()
        val y2 = (call.argument<Number>("y2"))?.toDouble()
        val duration = (call.argument<Number>("durationMs"))?.toLong() ?: 150L

        val replied = java.util.concurrent.atomic.AtomicBoolean(false)
        val accepted = service.performGesture(gesture, x, y, x2, y2, duration) { dispatched, completed ->
            if (replied.compareAndSet(false, true)) {
                Handler(Looper.getMainLooper()).post {
                    result.success(mapOf("dispatched" to dispatched, "completed" to completed))
                }
            }
        }
        if (!accepted && replied.compareAndSet(false, true)) {
            result.success(mapOf("dispatched" to false, "completed" to false))
        }
    }

    // ── Settings panels ─────────────────────────────────────────────

    private fun handleOpenSettingsPanel(call: MethodCall, result: MethodChannel.Result) {
        val panel = call.argument<String>("panel") ?: "internet"
        val opened = openPanelOrSettings(panel)
        result.success(mapOf("opened" to opened, "panel" to panel))
    }

    /**
     * Opens a Settings.Panel on API 29+ (in-context slide-up) or falls back
     * to a full settings screen on older releases. Returns true if an
     * activity was started.
     */
    private fun openPanelOrSettings(panel: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= 29) {
                val action = when (panel) {
                    "internet", "wifi" -> Settings.Panel.ACTION_INTERNET_CONNECTIVITY
                    "nfc" -> Settings.Panel.ACTION_NFC
                    "volume" -> Settings.Panel.ACTION_VOLUME
                    "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
                    else -> Settings.Panel.ACTION_INTERNET_CONNECTIVITY
                }
                val intent = Intent(action).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
                startActivity(intent)
                true
            } else {
                val action = when (panel) {
                    "wifi", "internet" -> Settings.ACTION_WIFI_SETTINGS
                    "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
                    "nfc" -> Settings.ACTION_NFC_SETTINGS
                    else -> Settings.ACTION_SETTINGS
                }
                val intent = Intent(action).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
                startActivity(intent)
                true
            }
        } catch (e: Exception) {
            false
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // PERMISSION STATUS CHECKS
    // ═══════════════════════════════════════════════════════════════

    /**
     * Check a permission status by its DevicePermission name.
     * Returns one of: "granted", "denied", "permanentlyDenied", "notRequested", "unknown"
     */
    private fun checkPermissionStatus(permName: String): String {
        return when (permName) {
            "microphone" -> checkRuntimePerm(Manifest.permission.RECORD_AUDIO)
            "camera" -> checkRuntimePerm(Manifest.permission.CAMERA)
            "notification" -> {
                if (Build.VERSION.SDK_INT >= 33) {
                    checkRuntimePerm(Manifest.permission.POST_NOTIFICATIONS)
                } else {
                    // Notifications are auto-granted on < API 33
                    "granted"
                }
            }
            "storage" -> {
                // API 33+ uses READ_MEDIA_IMAGES; API ≤32 uses READ_EXTERNAL_STORAGE
                if (Build.VERSION.SDK_INT >= 33) {
                    checkRuntimePerm(Manifest.permission.READ_MEDIA_IMAGES)
                } else {
                    @Suppress("DEPRECATION")
                    checkRuntimePerm(Manifest.permission.READ_EXTERNAL_STORAGE)
                }
            }
            "batteryOptimization" -> {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                val isIgnoring = pm.isIgnoringBatteryOptimizations(packageName)
                if (isIgnoring) "granted" else "denied"
            }
            "location" -> checkRuntimePerm(Manifest.permission.ACCESS_FINE_LOCATION)
            "exactAlarm" -> {
                if (Build.VERSION.SDK_INT >= 31) {
                    val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    if (am.canScheduleExactAlarms()) "granted" else "denied"
                } else {
                    "granted" // Auto-granted on < API 31
                }
            }
            "accessibility" -> {
                if (isAccessibilityEnabled()) "granted" else "denied"
            }
            "overlay" -> {
                if (Settings.canDrawOverlays(this)) "granted" else "denied"
            }
            "screenCapture" -> {
                // MediaProjection requires user approval each time; no persistent status
                "unknown"
            }
            "assistant" -> {
                if (isAuraDefaultAssistant()) "granted" else "denied"
            }
            else -> "unknown"
        }
    }

    private fun checkRuntimePerm(manifestPerm: String): String {
        val granted = checkSelfPermission(manifestPerm) == android.content.pm.PackageManager.PERMISSION_GRANTED
        return when {
            granted -> "granted"
            // We can't distinguish denied vs permanentlyDenied from native side
            // without going through the request flow, but we provide best effort.
            else -> "denied"
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SPECIAL PERMISSION REQUESTS (open relevant Settings page)
    // ═══════════════════════════════════════════════════════════════

    private fun requestSpecialPermission(permName: String) {
        when (permName) {
            "accessibility" -> {
                val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            }
            "overlay" -> {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            }
            "screenCapture" -> {
                // MediaProjection requires a system dialog, can't be launched from here.
                // User must trigger it via AURA's screen capture UI.
                // Open the screen capture / cast settings as a helpful fallback.
                val intent = Intent(Settings.ACTION_CAST_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            }
            "assistant" -> {
                // Keep this void request path crash-safe: openAssistantRoleSettings
                // may throw if no settings screen resolves. Fall back to the
                // top-level Settings rather than propagating an uncaught error.
                try {
                    openAssistantRoleSettings()
                } catch (e: Exception) {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                    } catch (_: Exception) { /* nothing else we can do */ }
                }
            }
            "batteryOptimization" -> {
                val intent = Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    Uri.parse("package:$packageName")
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            }
            "exactAlarm" -> {
                if (Build.VERSION.SDK_INT >= 31) {
                    val intent = Intent(
                        Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                        Uri.parse("package:$packageName")
                    ).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SPECIAL PERMISSION CHECK HELPERS
    // ═══════════════════════════════════════════════════════════════

    private fun isSpecialPermissionGranted(permName: String): Boolean {
        return when (permName) {
            "accessibility" -> isAccessibilityEnabled()
            "overlay" -> Settings.canDrawOverlays(this)
            "screenCapture" -> false // No persistent grant; must be requested per-session
            "assistant" -> isAuraDefaultAssistant()
            "batteryOptimization" -> {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                pm.isIgnoringBatteryOptimizations(packageName)
            }
            "exactAlarm" -> {
                if (Build.VERSION.SDK_INT >= 31) {
                    val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    am.canScheduleExactAlarms()
                } else true
            }
            else -> false
        }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabled = am.getEnabledAccessibilityServiceList(
            AccessibilityServiceInfo.FEEDBACK_ALL_MASK
        )
        return enabled.any { it.resolveInfo.serviceInfo.packageName == packageName }
    }

    // ═══════════════════════════════════════════════════════════════
    // ASSISTANT ROLE (P3)
    // ═══════════════════════════════════════════════════════════════

    /**
     * Returns 'active' if AURA is the default assistant,
     * 'available' if the device supports assistant role but AURA isn't default,
     * 'unsupported' if the RoleManager API isn't available (pre-API 29).
     */
    private fun getAssistantAvailability(): String {
        if (Build.VERSION.SDK_INT < 29) return "unsupported"
        val rm = getSystemService(Context.ROLE_SERVICE) as? RoleManager
            ?: return "unsupported"
        return try {
            // The set of roles can change with system updates, so we must query
            // availability rather than assume ROLE_ASSISTANT exists.
            if (!rm.isRoleAvailable(RoleManager.ROLE_ASSISTANT)) {
                "unsupported"
            } else if (rm.isRoleHeld(RoleManager.ROLE_ASSISTANT)) {
                "active"
            } else {
                "available"
            }
        } catch (e: Exception) {
            "unsupported"
        }
    }

    /** Whether the assistant role even exists / is queryable on this device. */
    private fun isAssistantRoleAvailable(): Boolean {
        if (Build.VERSION.SDK_INT < 29) return false
        val rm = getSystemService(Context.ROLE_SERVICE) as? RoleManager ?: return false
        return try { rm.isRoleAvailable(RoleManager.ROLE_ASSISTANT) } catch (e: Exception) { false }
    }

    private fun isAuraDefaultAssistant(): Boolean {
        if (Build.VERSION.SDK_INT < 29) return false
        val rm = getSystemService(Context.ROLE_SERVICE) as? RoleManager ?: return false
        return try {
            rm.isRoleAvailable(RoleManager.ROLE_ASSISTANT) &&
                rm.isRoleHeld(RoleManager.ROLE_ASSISTANT)
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Opens the system settings screen where the user can select AURA as the
     * default digital assistant, then returns a short route identifier.
     *
     * IMPORTANT — why we do NOT call createRequestRoleIntent(ROLE_ASSISTANT):
     * the assistant role is NOT requestable. Android's RequestRoleActivity
     * rejects it ("Role is not requestable: android.app.role.ASSISTANT") and
     * finishes immediately with RESULT_CANCELED, so the user sees nothing
     * happen. This was the actual bug: the button appeared dead. The supported
     * mechanism is to route the user to the "Assist & voice input" /
     * default-assistant settings page, where AURA already appears as a
     * candidate because MainActivity declares an ACTION_ASSIST intent-filter.
     *
     * Tries a prioritized list of real settings screens and launches the first
     * that resolves. Throws if none resolve — we never fake success.
     */
    private fun openAssistantRoleSettings(): String {
        val candidates = ArrayList<Pair<String, Intent>>()
        // Primary: the assist & voice-input page that hosts the default
        // digital assistant picker (available since API 21).
        candidates.add("voice_input_settings" to Intent(Settings.ACTION_VOICE_INPUT_SETTINGS))
        // Secondary: the "Default apps" hub (API 24+), whose child page is the
        // digital assistant selector on many OEM builds.
        if (Build.VERSION.SDK_INT >= 24) {
            candidates.add(
                "default_apps_settings" to Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)
            )
        }
        // Tertiary fallback: AURA's app details, from which the user can reach
        // "Set as default" on some devices.
        candidates.add(
            "app_details_settings" to Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName")
            )
        )
        // Last resort: the top-level Settings app.
        candidates.add("all_settings" to Intent(Settings.ACTION_SETTINGS))

        for ((route, intent) in candidates) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(packageManager) != null) {
                try {
                    startActivity(intent)
                    return route
                } catch (e: Exception) {
                    // Try the next candidate.
                }
            }
        }
        throw IllegalStateException(
            "No assistant / voice-input settings activity available on this device"
        )
    }

    /**
     * Extract invocation data from the launching intent.
     * When AURA is triggered as assistant (ACTION_ASSIST), the system provides:
     *   - EXTRA_ASSIST_PACKAGE: callingPackage
     *   - EXTRA_ASSIST_URI: assistUri (if a URI was shared)
     *   - EXTRA_ASSIST_CONTEXT: assistContext (clipboard / selected text)
     */
    private fun getInvocationDataFromIntent(): Map<String, String?> {
        val intent = intent ?: return emptyMap()
        return mapOf(
            "trigger" to when (intent.action) {
                Intent.ACTION_ASSIST -> "assistant_button"
                Intent.ACTION_PROCESS_TEXT -> "process_text"
                Intent.ACTION_MAIN -> "app_launch"
                else -> "unknown"
            },
            "callingPackage" to intent.getStringExtra(Intent.EXTRA_ASSIST_PACKAGE),
            "assistUri" to (intent.getParcelableExtra<Uri>("android.intent.extra.ASSIST_URI")?.toString()
                ?: intent.getStringExtra("android.intent.extra.ASSIST_URI")),
            "assistContext" to intent.getStringExtra(Intent.EXTRA_ASSIST_CONTEXT)
        )
    }

    // ═══════════════════════════════════════════════════════════════
    // PERMISSION SETTINGS HELPERS
    // ═══════════════════════════════════════════════════════════════

    private fun openPermissionSettings(permName: String) {
        when (permName) {
            "accessibility" -> requestSpecialPermission("accessibility")
            "overlay" -> requestSpecialPermission("overlay")
            "screenCapture" -> requestSpecialPermission("screenCapture")
            "assistant" -> requestSpecialPermission("assistant")
            "batteryOptimization" -> requestSpecialPermission("batteryOptimization")
            "exactAlarm" -> requestSpecialPermission("exactAlarm")
            else -> {
                // Generic: open app settings
                val intent = Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:$packageName")
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SETTINGS ACTION MAPPING
    // ═══════════════════════════════════════════════════════════════

    private fun mapSettingsAction(action: String): String {
        return when (action) {
            "wifi" -> Settings.ACTION_WIFI_SETTINGS
            "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
            "location" -> Settings.ACTION_LOCATION_SOURCE_SETTINGS
            "display" -> Settings.ACTION_DISPLAY_SETTINGS
            "sound" -> Settings.ACTION_SOUND_SETTINGS
            "battery" -> Settings.ACTION_BATTERY_SAVER_SETTINGS
            "apps" -> Settings.ACTION_APPLICATION_SETTINGS
            "storage" -> Settings.ACTION_INTERNAL_STORAGE_SETTINGS
            "security" -> Settings.ACTION_SECURITY_SETTINGS
            "about" -> Settings.ACTION_DEVICE_INFO_SETTINGS
            "accessibility" -> Settings.ACTION_ACCESSIBILITY_SETTINGS
            "notification" -> {
                if (Build.VERSION.SDK_INT >= 26) Settings.ACTION_APP_NOTIFICATION_SETTINGS
                else Settings.ACTION_APPLICATION_SETTINGS
            }
            "nfc" -> Settings.ACTION_NFC_SETTINGS
            "data_usage" -> Settings.ACTION_DATA_USAGE_SETTINGS
            "airplane" -> Settings.ACTION_AIRPLANE_MODE_SETTINGS
            else -> Settings.ACTION_SETTINGS
        }
    }

    private fun permToManifest(permName: String): String {
        return when (permName) {
            "microphone" -> Manifest.permission.RECORD_AUDIO
            "camera" -> Manifest.permission.CAMERA
            "notification" -> Manifest.permission.POST_NOTIFICATIONS
            "storage" -> {
                if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_IMAGES
                else @Suppress("DEPRECATION") Manifest.permission.READ_EXTERNAL_STORAGE
            }
            "location" -> Manifest.permission.ACCESS_FINE_LOCATION
            else -> ""
        }
    }
}
