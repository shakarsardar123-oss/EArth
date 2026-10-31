/// resource_profile_id.dart
/// AURA Assistant – Step 27: Battery & Thermal Optimization
///
/// Value object identifying a battery optimization profile.
library;

/// Strongly-typed identifier for a [BatteryOptimizationProfile].
class ResourceProfileId {
  final String value;

  const ResourceProfileId(this.value);

  static const unknown = ResourceProfileId('__unknown__');

  bool get isUnknown => value == '__unknown__' || value.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResourceProfileId && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ResourceProfileId($value)';
}
