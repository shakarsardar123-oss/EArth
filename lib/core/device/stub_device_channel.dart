/// Stub [DeviceChannel] that returns `platformUnsupported` for every
/// method.
///
/// Used on platforms where the native MethodChannel handler is not
/// available (e.g. iOS, web, desktop, or during unit tests that do
/// not pump the Flutter engine). This ensures tools degrade
/// gracefully instead of crashing.
library;

import 'device_channel.dart';
import '../../core/errors/result.dart';

class StubDeviceChannel implements DeviceChannel {
  /// Optional platform label included in error messages for
  /// debugging (e.g. 'ios', 'web').
  final String platformLabel;

  StubDeviceChannel({this.platformLabel = 'unsupported'});

  DeviceChannelResult _unsupported(String method) =>
      DeviceChannelResult.failure(
        '$method is not available on $platformLabel',
        errorCode: 'platformUnsupported',
      );

  @override
  Future<DeviceChannelResult> getDeviceInfo() async =>
      _unsupported('getDeviceInfo');

  @override
  Future<DeviceChannelResult> getBatteryInfo() async =>
      _unsupported('getBatteryInfo');

  @override
  Future<DeviceChannelResult> getNetworkInfo() async =>
      _unsupported('getNetworkInfo');

  @override
  Future<DeviceChannelResult> launchApp(String packageId) async =>
      _unsupported('launchApp');

  @override
  Future<DeviceChannelResult> openSystemSettings(String settingsAction) async =>
      _unsupported('openSystemSettings');

  @override
  Future<DeviceChannelResult> launchUrl(String url) async =>
      _unsupported('launchUrl');
}
