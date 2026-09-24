/// Abstract interface for platform-level device actions.
///
/// This abstraction decouples the Tool layer from any specific platform
/// mechanism (MethodChannel, FFI, etc.). Concrete implementations are
/// provided per platform — see [AndroidDeviceChannel] and [StubDeviceChannel].
///
/// Every method returns a [DeviceChannelResult] so that callers (tools)
/// never need to know whether the underlying call succeeded via
/// MethodChannel or was gracefully stubbed on an unsupported platform.
library;

import 'package:meta/meta.dart' show immutable;
import '../../core/errors/result.dart';

/// Outcome of a single device-channel invocation.
///
/// Mirrors the spirit of [ToolResult] but is self-contained so that
/// the channel layer does not depend on the Tool framework.
@immutable
class DeviceChannelResult {
  const DeviceChannelResult.success(this.data)
      : errorMessage = null,
        errorCode = null,
        isSuccess = true;

  const DeviceChannelResult.failure(this.errorMessage, {this.errorCode})
      : data = null,
        isSuccess = false;

  /// The payload on success.
  final Map<String, dynamic>? data;

  /// Human-readable error description on failure.
  final String? errorMessage;

  /// Machine-readable error code on failure.
  final String? errorCode;

  /// Whether the call succeeded.
  final bool isSuccess;

  @override
  String toString() {
    if (isSuccess) return 'DeviceChannelResult.success($data)';
    return 'DeviceChannelResult.failure($errorMessage, code: $errorCode)';
  }
}

/// Contract for all platform-level device operations.
///
/// Each method corresponds to a capability exposed through the native
/// Android MethodChannel (`com.texo.texo/device`).  The
/// [StubDeviceChannel] returns [DeviceChannelResult.failure] with
/// `platformUnsupported` for every method so that tools can degrade
/// gracefully on non-Android platforms.
abstract class DeviceChannel {
  // ── Device Information ──────────────────────────────────────────

  /// Returns a map of hardware and OS metadata.
  ///
  /// Keys: `brand`, `model`, `manufacturer`, `androidVersion`,
  /// `sdkInt`, `device`, `isPhysicalDevice`, `board`, `hardware`.
  Future<DeviceChannelResult> getDeviceInfo();

  // ── Battery ──────────────────────────────────────────────────────

  /// Returns battery level (0–100) and charging state.
  ///
  /// Keys: `level` (int), `isCharging` (bool), `chargingType`
  /// (`ac`, `usb`, `wireless`, `none`).
  Future<DeviceChannelResult> getBatteryInfo();

  // ── Network ──────────────────────────────────────────────────────

  /// Returns current connectivity status.
  ///
  /// Keys: `isConnected` (bool), `type` (`wifi`, `mobile`,
  /// `ethernet`, `none`, `unknown`), `networkName` (String?,
  /// may be null on mobile).
  Future<DeviceChannelResult> getNetworkInfo();

  // ── App Launch ───────────────────────────────────────────────────

  /// Launches the app with the given [packageId].
  ///
  /// Returns success with `{launched: true}` or failure with
  /// `appNotFound` / `launchFailed`.
  Future<DeviceChannelResult> launchApp(String packageId);

  // ── System Settings ──────────────────────────────────────────────

  /// Opens a system settings panel.
  ///
  /// [settingsAction] maps to Android `Settings.ACTION_*` constants.
  /// Common values: `wifi`, `bluetooth`, `location`, `display`,
  /// `sound`, `battery`, `apps`, `storage`, `security`, `about`.
  Future<DeviceChannelResult> openSystemSettings(String settingsAction);

  // ── URL Launching ───────────────────────────────────────────────

  /// Opens [url] in the default handler (browser, app, etc.).
  ///
  /// Returns success with `{launched: true}` or failure with
  /// `invalidUrl` / `launchFailed`.
  Future<DeviceChannelResult> launchUrl(String url);
}
