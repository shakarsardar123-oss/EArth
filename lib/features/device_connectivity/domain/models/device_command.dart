/// device_command.dart
/// AURA Assistant – Step 27: Cross-Device Connectivity & Control
///
/// Domain model for a command sent to a remote device.
/// FAIL-CLOSED: unknown → denied, unauthorized → denied,
///              unsupported device → denied.
library;

import 'package:meta/meta.dart';

/// Categories of remote device commands.
enum DeviceCommandType {
  mediaControl,
  navigation,
  textInput,
  tap,
  scroll,
  systemSetting,
  clipboard,
  notification,
  unknown,
  ;

  static DeviceCommandType fromName(String name) =>
      DeviceCommandType.values.firstWhere(
        (e) => e.name == name,
        orElse: () => DeviceCommandType.unknown,
      );

  /// FAIL-CLOSED: unknown commands are never authorizable.
  bool get isAuthorizable => this != unknown;
}

/// Result of executing a remote device command.
enum DeviceCommandResult {
  success,
  failure,
  denied,
  timedOut,
  unsupported,
  unknown,
  ;

  static DeviceCommandResult fromName(String name) =>
      DeviceCommandResult.values.firstWhere(
        (e) => e.name == name,
        orElse: () => DeviceCommandResult.unknown,
      );

  /// FAIL-CLOSED: unknown results are never successful.
  bool get isSuccess => this == success;
  bool get isFailure =>
      this == failure || this == denied || this == timedOut ||
      this == unsupported || this == unknown;
}

/// Immutable remote device command.
@immutable
class DeviceCommand {
  /// Unique command identifier.
  final String commandId;

  /// Target connection identifier.
  final String connectionId;

  /// Target device identifier.
  final String deviceId;

  /// Command type.
  final DeviceCommandType type;

  /// Command payload (e.g. coordinates, text, setting key).
  final Map<String, dynamic> payload;

  /// Whether this command requires user confirmation.
  final bool requiresConfirmation;

  /// Risk level: 'low', 'medium', 'high', 'critical'.
  final String riskLevel;

  /// Locale — Kurdish Sorani RTL first.
  final String locale;

  /// Timestamp when the command was created.
  final DateTime createdAt;

  const DeviceCommand({
    required this.commandId,
    required this.connectionId,
    required this.deviceId,
    required this.type,
    this.payload = const {},
    this.requiresConfirmation = true,
    this.riskLevel = 'high',
    this.locale = 'ku',
    required this.createdAt,
  });

  /// FAIL-CLOSED: factory for unknown/unrecognized commands.
  factory DeviceCommand.unknown({
    required String commandId,
    required String connectionId,
  }) =>
      DeviceCommand(
        commandId: commandId,
        connectionId: connectionId,
        deviceId: 'unknown',
        type: DeviceCommandType.unknown,
        riskLevel: 'critical',
        createdAt: DateTime.now(),
        locale: 'ku',
      );

  /// FAIL-CLOSED: unknown commands are never authorizable.
  bool get isAuthorizable => type.isAuthorizable;

  @override
  String toString() =>
      'DeviceCommand(id: $commandId, type: $type, device: $deviceId)';
}
