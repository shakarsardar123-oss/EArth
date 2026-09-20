/// device_connection_state.dart
/// AURA Assistant – Step 27: Cross-Device Connectivity & Control
///
/// Domain model for the state of a cross-device connection.
/// FAIL-CLOSED: unknown → disconnected, error → disconnected,
///              unavailable → disconnected, unauthorized → disconnected.
/// Kurdish Sorani RTL-first: locale defaults to 'ku'.
library;

import 'package:meta/meta.dart';

/// Connection state of a cross-device link.
enum DeviceConnectionStatus {
  /// Actively connected and authenticated.
  connected,

  /// Connection is being established.
  connecting,

  /// Disconnected (intentional or idle).
  disconnected,

  /// Connection failed — fail-closed.
  failed,

  /// Connection denied by security gate — fail-closed.
  denied,

  /// Unknown state — treated as disconnected (fail-closed).
  unknown,
  ;

  /// FAIL-CLOSED: any unknown name maps to [unknown].
  static DeviceConnectionStatus fromName(String name) {
    return DeviceConnectionStatus.values.firstWhere(
      (e) => e.name == name,
      orElse: () => DeviceConnectionStatus.unknown,
    );
  }

  /// Whether this status represents an active usable connection.
  bool get isConnected => this == connected;

  /// Whether this status blocks interaction (fail-closed check).
  bool get isBlocking =>
      this == disconnected || this == failed || this == denied || this == unknown;
}

/// Transport protocol for device connections.
enum DeviceTransport {
  bluetooth,
  wifiDirect,
  usb,
  localNetwork,
  unknown,
  ;

  static DeviceTransport fromName(String name) =>
      DeviceTransport.values.firstWhere(
        (e) => e.name == name,
        orElse: () => DeviceTransport.unknown,
      );
}

/// Immutable device connection state.
@immutable
class DeviceConnectionState {
  /// Unique connection identifier.
  final String connectionId;

  /// Target device identifier.
  final String deviceId;

  /// Human-readable device name.
  final String deviceName;

  /// Current connection status.
  final DeviceConnectionStatus status;

  /// Transport protocol in use.
  final DeviceTransport transport;

  /// Timestamp of last status change.
  final DateTime lastUpdated;

  /// Signal strength (0-100, -1 if unavailable).
  final int signalStrength;

  /// Whether the connection is authenticated.
  final bool isAuthenticated;

  /// Whether the remote device is authorized for control.
  final bool isControlAuthorized;

  /// Locale for localization — Kurdish Sorani RTL first: 'ku'.
  final String locale;

  /// Additional metadata (device capabilities, etc.).
  final Map<String, dynamic> metadata;

  const DeviceConnectionState({
    required this.connectionId,
    required this.deviceId,
    required this.deviceName,
    this.status = DeviceConnectionStatus.disconnected,
    this.transport = DeviceTransport.unknown,
    required this.lastUpdated,
    this.signalStrength = -1,
    this.isAuthenticated = false,
    this.isControlAuthorized = false,
    this.locale = 'ku',
    this.metadata = const {},
  });

  /// FAIL-CLOSED: factory for unknown/invalid connections.
  factory DeviceConnectionState.unknown({
    required String connectionId,
    String deviceId = 'unknown',
  }) =>
      DeviceConnectionState(
        connectionId: connectionId,
        deviceId: deviceId,
        deviceName: 'unknown',
        status: DeviceConnectionStatus.unknown,
        lastUpdated: DateTime.now(),
        locale: 'ku',
      );

  /// FAIL-CLOSED: factory for denied connections.
  factory DeviceConnectionState.denied({
    required String connectionId,
    required String deviceId,
    String? reason,
  }) =>
      DeviceConnectionState(
        connectionId: connectionId,
        deviceId: deviceId,
        deviceName: '',
        status: DeviceConnectionStatus.denied,
        lastUpdated: DateTime.now(),
        locale: 'ku',
        metadata: {'denyReason': reason ?? 'Security gate denied connection'},
      );

  /// FAIL-CLOSED: unknown status is never usable.
  bool get isUsable =>
      status.isConnected && isAuthenticated && isControlAuthorized;

  DeviceConnectionState copyWith({
    DeviceConnectionStatus? status,
    int? signalStrength,
    bool? isAuthenticated,
    bool? isControlAuthorized,
    Map<String, dynamic>? metadata,
  }) =>
      DeviceConnectionState(
        connectionId: connectionId,
        deviceId: deviceId,
        deviceName: deviceName,
        status: status ?? this.status,
        transport: transport,
        lastUpdated: DateTime.now(),
        signalStrength: signalStrength ?? this.signalStrength,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        isControlAuthorized: isControlAuthorized ?? this.isControlAuthorized,
        locale: locale,
        metadata: metadata ?? this.metadata,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceConnectionState && connectionId == other.connectionId;

  @override
  int get hashCode => connectionId.hashCode;

  @override
  String toString() =>
      'DeviceConnectionState(id: $connectionId, device: $deviceId, '
      'status: $status, auth: $isAuthenticated)';
}
