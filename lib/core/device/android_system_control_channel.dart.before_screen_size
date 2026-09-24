/// Concrete [SystemControlChannel] backed by an Android [MethodChannel].
///
/// Channel name: `com.aura.aura_assistant/system_control`
/// (a NEW channel, separate from the existing device channel, so no
/// pre-existing handler or Dart wrapper is disturbed).
///
/// Every call is forwarded to the Kotlin handler in `MainActivity.kt`.
/// On non-Android platforms (or when the plugin is missing) the call is
/// caught and converted into a `platformUnsupported` failure so callers
/// degrade gracefully instead of throwing.
library;

import 'package:flutter/services.dart';
import 'system_control_channel.dart';
import '../../core/errors/result.dart';

/// Method names shared verbatim between Flutter and Kotlin.
abstract class SystemControlMethods {
  static const String getBluetoothState = 'getBluetoothState';
  static const String setBluetoothEnabled = 'setBluetoothEnabled';
  static const String getWifiState = 'getWifiState';
  static const String setWifiEnabled = 'setWifiEnabled';
  static const String getMemoryInfo = 'getMemoryInfo';
  static const String optimizeResources = 'optimizeResources';
  static const String isAccessibilityServiceEnabled =
      'isAccessibilityServiceEnabled';
  static const String dispatchGesture = 'dispatchGesture';
  static const String openSettingsPanel = 'openSettingsPanel';
}

class AndroidSystemControlChannel implements SystemControlChannel {
  static const MethodChannel _channel =
      MethodChannel('com.aura.aura_assistant/system_control');

  @override
  Future<DeviceChannelResult> getBluetoothState() =>
      _invoke(SystemControlMethods.getBluetoothState);

  @override
  Future<DeviceChannelResult> setBluetoothEnabled(bool enable) =>
      _invoke(SystemControlMethods.setBluetoothEnabled, {'enable': enable});

  @override
  Future<DeviceChannelResult> getWifiState() =>
      _invoke(SystemControlMethods.getWifiState);

  @override
  Future<DeviceChannelResult> setWifiEnabled(bool enable) =>
      _invoke(SystemControlMethods.setWifiEnabled, {'enable': enable});

  @override
  Future<DeviceChannelResult> getMemoryInfo() =>
      _invoke(SystemControlMethods.getMemoryInfo);

  @override
  Future<DeviceChannelResult> optimizeResources() =>
      _invoke(SystemControlMethods.optimizeResources);

  @override
  Future<DeviceChannelResult> isAccessibilityServiceEnabled() =>
      _invoke(SystemControlMethods.isAccessibilityServiceEnabled);

  @override
  Future<DeviceChannelResult> dispatchGesture({
    required String gesture,
    required double x,
    required double y,
    double? x2,
    double? y2,
    int durationMs = 150,
  }) =>
      _invoke(SystemControlMethods.dispatchGesture, {
        'gesture': gesture,
        'x': x,
        'y': y,
        if (x2 != null) 'x2': x2,
        if (y2 != null) 'y2': y2,
        'durationMs': durationMs,
      });

  @override
  Future<DeviceChannelResult> openSettingsPanel(String panel) =>
      _invoke(SystemControlMethods.openSettingsPanel, {'panel': panel});

  // ── Private helper ───────────────────────────────────────────

  Future<DeviceChannelResult> _invoke(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    try {
      final dynamic raw = await _channel.invokeMethod(method, arguments);
      if (raw is Map) {
        // MethodChannel decodes maps as Map<Object?, Object?>; normalise to
        // the Map<String, dynamic> shape the tools expect.
        return DeviceChannelResult.success(
          raw.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
      return DeviceChannelResult.success({'value': raw});
    } on PlatformException catch (e) {
      return DeviceChannelResult.failure(
        e.message ?? 'Platform error on $method',
        errorCode: e.code,
      );
    } on MissingPluginException {
      return DeviceChannelResult.failure(
        'Method $method is not implemented on this platform',
        errorCode: 'platformUnsupported',
      );
    } on ArgumentError catch (e) {
      return DeviceChannelResult.failure(
        'Invalid arguments for $method: ${e.message}',
        errorCode: 'invalidArguments',
      );
    } catch (e) {
      return DeviceChannelResult.failure(
        'Unexpected error on $method: $e',
        errorCode: 'internalError',
      );
    }
  }
}
