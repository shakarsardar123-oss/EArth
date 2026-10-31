/// resource_state.dart
/// AURA Assistant – Step 27: Battery & Thermal Optimization
///
/// Domain model for the current resource (battery/thermal) state.
/// FAIL-CLOSED: unknown → critical, unavailable → critical.
library;

import 'package:meta/meta.dart';

/// Thermal status levels.
enum ThermalStatus {
  nominal,
  fair,
  serious,
  critical,
  unknown,
  ;

  static ThermalStatus fromName(String name) =>
      ThermalStatus.values.firstWhere(
        (e) => e.name == name,
        orElse: () => ThermalStatus.unknown,
      );

  /// FAIL-CLOSED: unknown is treated as critical.
  bool get isCritical => this == critical || this == unknown;
  bool get isNominal => this == nominal;
  bool get needsThrottling => this == serious || this == critical || this == unknown;
}

/// Battery level categories.
enum BatteryLevel {
  full,
  high,
  medium,
  low,
  critical,
  unknown,
  ;

  static BatteryLevel fromValue(double value) {
    if (value >= 0.9) return BatteryLevel.full;
    if (value >= 0.7) return BatteryLevel.high;
    if (value >= 0.4) return BatteryLevel.medium;
    if (value >= 0.2) return BatteryLevel.low;
    return BatteryLevel.critical;
  }

  bool get isCritical => this == critical || this == unknown;
  bool get isLow => this == low || this == critical || this == unknown;
  bool get needsOptimization =>
      this == low || this == critical || this == unknown;
}

/// Power source.
enum PowerSource {
  battery,
  charging,
  full,
  unknown,
  ;

  bool get isOnBattery => this == battery || this == unknown;
}

/// Immutable resource state.
@immutable
class ResourceState {
  /// Battery level (0.0-1.0).
  final double batteryLevel;

  /// Battery level category.
  final BatteryLevel batteryCategory;

  /// Whether the device is charging.
  final bool isCharging;

  /// Power source.
  final PowerSource powerSource;

  /// Thermal status.
  final ThermalStatus thermalStatus;

  /// CPU usage (0.0-1.0).
  final double cpuUsage;

  /// Memory usage (0.0-1.0).
  final double memoryUsage;

  /// Whether low-power mode is active.
  final bool lowPowerMode;

  /// Locale — Kurdish Sorani RTL first.
  final String locale;

  /// Timestamp of measurement.
  final DateTime measuredAt;

  const ResourceState({
    this.batteryLevel = 0.0,
    this.batteryCategory = BatteryLevel.unknown,
    this.isCharging = false,
    this.powerSource = PowerSource.unknown,
    this.thermalStatus = ThermalStatus.unknown,
    this.cpuUsage = 0.0,
    this.memoryUsage = 0.0,
    this.lowPowerMode = false,
    this.locale = 'ku',
    required this.measuredAt,
  });

  /// FAIL-CLOSED: unknown state → critical.
  factory ResourceState.unknown() => ResourceState(
        batteryLevel: 0.0,
        batteryCategory: BatteryLevel.unknown,
        thermalStatus: ThermalStatus.unknown,
        powerSource: PowerSource.unknown,
        measuredAt: DateTime.now(),
      );

  /// FAIL-CLOSED: critical resource state.
  bool get isCritical =>
      batteryCategory.isCritical || thermalStatus.isCritical;

  /// Whether optimization should be active.
  bool get needsOptimization =>
      batteryCategory.needsOptimization || thermalStatus.needsThrottling;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResourceState && measuredAt == other.measuredAt;

  @override
  int get hashCode => measuredAt.hashCode;

  @override
  String toString() =>
      'ResourceState(battery: $batteryCategory, thermal: $thermalStatus, '
      'charging: $isCharging, lowPower: $lowPowerMode)';
}
