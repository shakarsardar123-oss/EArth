/// Concrete [DeviceChannel] backed by an Android [MethodChannel].
///
/// Channel name: `com.aura.aura_assistant/device`
///
/// Every method call is forwarded to the Kotlin handler in
/// `MainActivity.kt`. If the platform is not Android (e.g. iOS in
/// a future build, or a desktop test runner), the call is caught
/// and a `platformUnsupported` failure is returned.
library;

import 'package:flutter/services.dart';
import 'device_channel.dart';
import '../../core/errors/result.dart';

/// Method names shared between Flutter and Kotlin.
///
/// Keeping them as constants prevents typos and makes it easy to
/// grep for all cross-boundary calls.
abstract class DeviceMethodNames {
  static const String getDeviceInfo = 'getDeviceInfo';
  static const String getBatteryInfo = 'getBatteryInfo';
  static const String getNetworkInfo = 'getNetworkInfo';
  static const String launchApp = 'launchApp';
  static const String openSystemSettings = 'openSystemSettings';
  static const String launchUrl = 'launchUrl';
}

class AndroidDeviceChannel implements DeviceChannel {
  /// The single shared MethodChannel for all device actions.
  static const MethodChannel _channel =
      MethodChannel('com.aura.aura_assistant/device');

  @override
  Future<DeviceChannelResult> getDeviceInfo() =>
      _invokeMethod(DeviceMethodNames.getDeviceInfo);

  @override
  Future<DeviceChannelResult> getBatteryInfo() =>
      _invokeMethod(DeviceMethodNames.getBatteryInfo);

  @override
  Future<DeviceChannelResult> getNetworkInfo() =>
      _invokeMethod(DeviceMethodNames.getNetworkInfo);

  @override
  Future<DeviceChannelResult> launchApp(String packageId) =>
      _invokeMethod(DeviceMethodNames.launchApp, {'packageId': packageId});

  @override
  Future<DeviceChannelResult> openSystemSettings(String settingsAction) =>
      _invokeMethod(
          DeviceMethodNames.openSystemSettings, {'action': settingsAction},);

  @override
  Future<DeviceChannelResult> launchUrl(String url) =>
      _invokeMethod(DeviceMethodNames.launchUrl, {'url': url});

  // ── Private helpers ──────────────────────────────────────────────

  /// Invokes a method on the channel, converting the raw result
  /// into a [DeviceChannelResult].
  ///
  /// Catches [PlatformException] and [MissingPluginException] and
  /// converts them to failures with well-known error codes.
  Future<DeviceChannelResult> _invokeMethod(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    try {
      final dynamic raw = await _channel.invokeMethod(method, arguments);
      if (raw is Map<String, dynamic>) {
        return DeviceChannelResult.success(raw);
      }
      // If the native side returns a non-map success (unlikely but
      // defensive), wrap it.
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
