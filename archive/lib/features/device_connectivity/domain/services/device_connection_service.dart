/// device_connection_service.dart
/// AURA Assistant – Step 27: Cross-Device Connectivity & Control
///
/// Abstract domain service for managing cross-device connections.
/// FAIL-CLOSED: unknown → disconnected, error → disconnected,
///              unavailable → disconnected, unauthorized → disconnected.
/// All device control commands MUST route through ToolConfirmationService
/// from Step 20 when requiresConfirmation is true.
library;

import '../models/device_connection_state.dart';
import '../models/device_command.dart';

/// Security verdict for device operations.
enum DeviceSecurityVerdict {
  allowed,
  denied,
  unknown,
  ;

  /// FAIL-CLOSED: unknown → denied.
  bool get isAllowed => this == allowed;
}

/// Abstract service for cross-device connection management.
abstract class DeviceConnectionService {
  /// Discover available remote devices.
  /// FAIL-CLOSED: error → empty list, unavailable → empty list.
  Future<List<DeviceConnectionState>> discoverDevices();

  /// Connect to a remote device.
  /// FAIL-CLOSED: unknown device → denied, auth failure → denied.
  Future<DeviceConnectionState> connect(String deviceId, String transport);

  /// Disconnect from a remote device.
  /// FAIL-CLOSED: unknown device → disconnected state.
  Future<DeviceConnectionState> disconnect(String connectionId);

  /// Get the current state of a connection.
  /// FAIL-CLOSED: unknown connection → unknown state.
  DeviceConnectionState getConnectionState(String connectionId);

  /// Send a command to a remote device.
  /// FAIL-CLOSED: unauthorized → denied, unknown device → denied,
  ///              unconfirmed high-risk → denied.
  Future<DeviceCommandResult> sendCommand(DeviceCommand command);

  /// Check whether the device connectivity subsystem is available.
  Future<bool> isAvailable();

  /// Authorize a device for control.
  /// FAIL-CLOSED: unknown → denied, error → denied.
  Future<DeviceSecurityVerdict> authorizeDevice(String deviceId);
}
