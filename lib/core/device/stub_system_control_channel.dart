/// Fail-closed [SystemControlChannel] for non-Android platforms and unit
/// tests. Every method returns a `platformUnsupported` failure so tools
/// degrade gracefully instead of crashing.
library;

import 'system_control_channel.dart';
import '../../core/errors/result.dart';

class StubSystemControlChannel implements SystemControlChannel {
  StubSystemControlChannel({this.platformLabel = 'unsupported'});

  /// Platform label included in error messages (e.g. 'ios', 'linux').
  final String platformLabel;

  DeviceChannelResult _unsupported(String method) =>
      DeviceChannelResult.failure(
        '$method is not available on $platformLabel',
        errorCode: 'platformUnsupported',
      );

  @override
  Future<DeviceChannelResult> getBluetoothState() async =>
      _unsupported('getBluetoothState');

  @override
  Future<DeviceChannelResult> setBluetoothEnabled(bool enable) async =>
      _unsupported('setBluetoothEnabled');

  @override
  Future<DeviceChannelResult> getWifiState() async =>
      _unsupported('getWifiState');

  @override
  Future<DeviceChannelResult> setWifiEnabled(bool enable) async =>
      _unsupported('setWifiEnabled');

  @override
  Future<DeviceChannelResult> getMemoryInfo() async =>
      _unsupported('getMemoryInfo');

  @override
  Future<DeviceChannelResult> optimizeResources() async =>
      _unsupported('optimizeResources');

  @override
  Future<DeviceChannelResult> isAccessibilityServiceEnabled() async =>
      _unsupported('isAccessibilityServiceEnabled');

  @override
  Future<DeviceChannelResult> getScreenSize() async =>
      const DeviceChannelResult.failure(
        'Screen size is not supported on this platform',
        errorCode: 'platformUnsupported',
      );

  @override
  Future<DeviceChannelResult> dispatchGesture({
    required String gesture,
    required double x,
    required double y,
    double? x2,
    double? y2,
    int durationMs = 150,
  }) async =>
      _unsupported('dispatchGesture');

  @override
  Future<DeviceChannelResult> openSettingsPanel(String panel) async =>
      _unsupported('openSettingsPanel');
}
