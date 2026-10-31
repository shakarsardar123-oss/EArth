/// battery_optimization_profile.dart
/// AURA Assistant – Step 27: Battery & Thermal Optimization
///
/// Domain model for battery optimization profile.
/// FAIL-CLOSED: unknown → maximum savings (most restrictive).
library;

import 'package:meta/meta.dart';
import 'resource_state.dart' show BatteryLevel, ThermalStatus;

/// Optimization level.
enum OptimizationLevel {
  none,
  minimal,
  moderate,
  aggressive,
  maximum,
  unknown,
  ;

  /// FAIL-CLOSED: unknown → maximum.
  static OptimizationLevel forResourceState({
    required BatteryLevel battery,
    required ThermalStatus thermal,
  }) {
    if (battery.isCritical || thermal.isCritical) return maximum;
    if (battery.isLow || thermal.needsThrottling) return aggressive;
    if (battery == BatteryLevel.medium) return moderate;
    return minimal;
  }

  bool get isNone => this == none;
  bool get isMaximum => this == maximum || this == unknown;
  int get throttlePercent => switch (this) {
        none => 0,
        minimal => 10,
        moderate => 30,
        aggressive => 60,
        maximum => 90,
        unknown => 90,
      };
}

/// Immutable battery optimization profile.
@immutable
class BatteryOptimizationProfile {
  /// Profile identifier.
  final String profileId;

  /// Optimization level.
  final OptimizationLevel level;

  /// Whether background processing is allowed.
  final bool allowBackgroundProcessing;

  /// Whether continuous listening is allowed.
  final bool allowContinuousListening;

  /// Whether real-time translation is allowed.
  final bool allowRealTimeTranslation;

  /// Whether screen detection is allowed.
  final bool allowScreenDetection;

  /// Whether subtitle overlay is allowed.
  final bool allowSubtitleOverlay;

  /// Maximum CPU usage allowed (0.0-1.0).
  final double maxCpuUsage;

  /// Maximum memory usage allowed (0.0-1.0).
  final double maxMemoryUsage;

  /// STT language throttle — if true, skip non-essential STT.
  final bool throttleStt;

  /// Locale — Kurdish Sorani RTL first.
  final String locale;

  const BatteryOptimizationProfile({
    required this.profileId,
    this.level = OptimizationLevel.unknown,
    this.allowBackgroundProcessing = false,
    this.allowContinuousListening = false,
    this.allowRealTimeTranslation = false,
    this.allowScreenDetection = false,
    this.allowSubtitleOverlay = false,
    this.maxCpuUsage = 0.5,
    this.maxMemoryUsage = 0.5,
    this.throttleStt = true,
    this.locale = 'ku',
  });

  /// FAIL-CLOSED: maximum savings profile (most restrictive).
  factory BatteryOptimizationProfile.maximumSavings({
    required String profileId,
  }) =>
      const BatteryOptimizationProfile(
        profileId: 'max_savings',
        level: OptimizationLevel.maximum,
        allowBackgroundProcessing: false,
        allowContinuousListening: false,
        allowRealTimeTranslation: false,
        allowScreenDetection: false,
        allowSubtitleOverlay: false,
        maxCpuUsage: 0.3,
        maxMemoryUsage: 0.3,
        throttleStt: true,
      );

  /// Default profile (nominal operation).
  factory BatteryOptimizationProfile.nominal({
    required String profileId,
  }) =>
      const BatteryOptimizationProfile(
        profileId: profileId,
        level: OptimizationLevel.minimal,
        allowBackgroundProcessing: true,
        allowContinuousListening: true,
        allowRealTimeTranslation: true,
        allowScreenDetection: true,
        allowSubtitleOverlay: true,
        maxCpuUsage: 0.8,
        maxMemoryUsage: 0.8,
        throttleStt: false,
      );

  /// Whether any features are allowed.
  bool get anyFeaturesAllowed =>
      allowBackgroundProcessing ||
      allowContinuousListening ||
      allowRealTimeTranslation ||
      allowScreenDetection ||
      allowSubtitleOverlay;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatteryOptimizationProfile && profileId == other.profileId;

  @override
  int get hashCode => profileId.hashCode;

  @override
  String toString() =>
      'BatteryOptimizationProfile(id: $profileId, level: $level, '
      'bg: $allowBackgroundProcessing, listening: $allowContinuousListening)';
}
