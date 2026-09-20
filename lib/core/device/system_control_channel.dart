/// Phase 6 — System Control Channel.
///
/// A **separate, additive** platform-channel abstraction for the six
/// real actuation capabilities added in Phase 6:
///   * Bluetooth state / toggle
///   * Wi-Fi state / toggle / scan
///   * Memory (RAM) info + resource-optimization actuation
///   * AccessibilityService availability + screen-gesture dispatch
///   * System settings-panel launching (Wi-Fi / Bluetooth quick panels)
///
/// It is intentionally kept apart from the pre-existing [DeviceChannel]
/// so that none of the many existing `implements DeviceChannel` sites
/// (tools + tests) are disturbed. This honours the Phase 6 rule:
/// **additive only, never rebuild/duplicate the existing architecture.**
///
/// Every method returns a [DeviceChannelResult] (reused from
/// `device_channel.dart`) so the tool layer degrades gracefully and never
/// needs to know whether the call reached Kotlin or was stubbed.
library;

import 'device_channel.dart' show DeviceChannelResult;

export 'device_channel.dart' show DeviceChannelResult;

/// Contract for Phase 6 platform-level *system-control* operations.
///
/// Concrete implementations:
///   * [AndroidSystemControlChannel] — real Android MethodChannel.
///   * [StubSystemControlChannel]    — fail-closed on unsupported platforms.
abstract class SystemControlChannel {
  // ── Bluetooth ────────────────────────────────────────────────────

  /// Reads the current Bluetooth adapter state.
  ///
  /// Success keys: `supported` (bool), `enabled` (bool).
  Future<DeviceChannelResult> getBluetoothState();

  /// Requests enabling/disabling Bluetooth.
  ///
  /// On API < 33 with BLUETOOTH_ADMIN this toggles directly and the
  /// result reports the **verified** post-toggle state. On API >= 33 the
  /// direct toggle API is a no-op, so this opens the appropriate system
  /// surface and returns `requiresUserAction: true` (never claims a state
  /// change it cannot perform).
  ///
  /// Success keys: `requested` (bool), `enabled` (bool, verified state),
  /// `method` (`direct` | `settings_panel` | `request_enable`),
  /// `requiresUserAction` (bool).
  Future<DeviceChannelResult> setBluetoothEnabled(bool enable);

  // ── Wi-Fi ────────────────────────────────────────────────────────

  /// Reads the current Wi-Fi enabled state.
  ///
  /// Success keys: `enabled` (bool), `ssid` (String?, may be null).
  Future<DeviceChannelResult> getWifiState();

  /// Requests enabling/disabling Wi-Fi.
  ///
  /// On API < 29 uses `WifiManager.setWifiEnabled` directly and returns the
  /// verified state. On API >= 29 that call always fails by OS policy, so
  /// this opens the Wi-Fi settings panel and returns
  /// `requiresUserAction: true`.
  ///
  /// Success keys mirror [setBluetoothEnabled].
  Future<DeviceChannelResult> setWifiEnabled(bool enable);

  // ── Memory / resource optimization ───────────────────────────────

  /// Reads current RAM usage from `ActivityManager.MemoryInfo`.
  ///
  /// Success keys: `totalMem` (int bytes), `availMem` (int bytes),
  /// `lowMemory` (bool), `threshold` (int bytes),
  /// `appJavaHeapUsedBytes` (int), `appNativeHeapUsedBytes` (int).
  Future<DeviceChannelResult> getMemoryInfo();

  /// Performs a **real, in-process** resource-optimization pass and
  /// returns a verified before/after RAM delta.
  ///
  /// The actuation is honest and bounded to what an unprivileged app may
  /// legitimately do: release the app's own memory caches, hint the VM to
  /// collect (`Runtime.gc()`), and — when the KILL_BACKGROUND_PROCESSES
  /// permission is held — request the OS trim other apps' background
  /// processes. It never claims to have freed memory it did not.
  ///
  /// Success keys: `beforeAvailMem` (int), `afterAvailMem` (int),
  /// `freedBytes` (int, may be 0 or negative under load),
  /// `killedBackground` (bool), `actions` (List<String>).
  Future<DeviceChannelResult> optimizeResources();

  // ── Accessibility gesture ────────────────────────────────────────

  /// Whether AURA's [AuraAccessibilityService] is currently enabled AND
  /// bound (i.e. gestures can actually be dispatched right now).
  ///
  /// Success keys: `enabled` (bool).
  Future<DeviceChannelResult> isAccessibilityServiceEnabled();

  /// Dispatches a screen gesture through the AccessibilityService.
  ///
  /// [gesture] is one of `tap`, `long_press`, `swipe`. Coordinates are in
  /// absolute screen pixels. For `swipe`, [x2]/[y2] are the end point.
  /// [durationMs] tunes the gesture stroke duration.
  ///
  /// Fails closed with `accessibilityDisabled` when the service is not
  /// bound, and `platformUnsupported` on API < 24 (gesture dispatch API).
  ///
  /// Success keys: `dispatched` (bool), `completed` (bool).
  Future<DeviceChannelResult> dispatchGesture({
    required String gesture,
    required double x,
    required double y,
    double? x2,
    double? y2,
    int durationMs = 150,
  });

  // ── Settings panels ──────────────────────────────────────────────

  /// Opens a system settings panel (`internet`, `wifi`, `bluetooth`,
  /// `nfc`, `volume`) using `Settings.Panel` on API 29+ or an equivalent
  /// settings intent on older releases.
  ///
  /// Success keys: `opened` (bool), `panel` (String).
  Future<DeviceChannelResult> openSettingsPanel(String panel);
}
