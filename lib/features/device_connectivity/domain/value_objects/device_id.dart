/// device_id.dart
/// AURA Assistant – Step 27: Device ID value object.
///
/// Typed identifier for a remote device.
/// FAIL-CLOSED: empty/null → invalid.
library;

import 'package:meta/meta.dart';

@immutable
class DeviceId {
  final String value;

  const DeviceId(this.value);

  /// FAIL-CLOSED: empty or null values are invalid.
  bool get isValid => value.isNotEmpty;

  /// Factory for unknown device IDs.
  factory DeviceId.unknown() => const DeviceId('unknown');

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DeviceId && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'DeviceId($value)';
}
