/// Android assistant role status.
///
/// Represents whether the Android device supports the default-assistant
/// mechanism, and whether AURA is currently the default assistant.
///
/// This entity is immutable and value-based.
library;

/// Whether the assistant feature is available on this device/platform.
enum AssistantAvailability {
  /// The platform does not support the assistant role at all
  /// (e.g. non-Android, or Android version too old).
  unsupported,

  /// The platform supports the assistant role but the role is currently
  /// taken by another app.
  available,

  /// AURA is currently set as the default assistant.
  active,
}

/// Immutable snapshot of the assistant status.
class AssistantStatus {
  /// Whether the device supports the assistant integration.
  final AssistantAvailability availability;

  /// The package name of the current default assistant, if known.
  /// Null if AURA is the default, or if the information is unavailable.
  final String? currentDefaultPackage;

  /// Android API level of the device (null on non-Android).
  final int? androidApiLevel;

  /// Timestamp of the last status check.
  final DateTime? lastChecked;

  const AssistantStatus({
    this.availability = AssistantAvailability.unsupported,
    this.currentDefaultPackage,
    this.androidApiLevel,
    this.lastChecked,
  });

  /// Whether AURA is currently the default assistant.
  bool get isAuraDefault => availability == AssistantAvailability.active;

  /// Whether the assistant role can be requested (i.e. platform supports it
  /// but AURA is not yet default).
  bool get canRequestDefault =>
      availability == AssistantAvailability.available;

  /// Whether the platform does not support assistant integration at all.
  bool get isUnsupported => availability == AssistantAvailability.unsupported;

  AssistantStatus copyWith({
    AssistantAvailability? availability,
    String? currentDefaultPackage,
    bool clearCurrentDefaultPackage = false,
    int? androidApiLevel,
    DateTime? lastChecked,
  }) {
    return AssistantStatus(
      availability: availability ?? this.availability,
      currentDefaultPackage: clearCurrentDefaultPackage
          ? null
          : (currentDefaultPackage ?? this.currentDefaultPackage),
      androidApiLevel: androidApiLevel ?? this.androidApiLevel,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssistantStatus &&
          availability == other.availability &&
          currentDefaultPackage == other.currentDefaultPackage &&
          androidApiLevel == other.androidApiLevel;

  @override
  int get hashCode =>
      Object.hash(availability, currentDefaultPackage, androidApiLevel);

  @override
  String toString() =>
      'AssistantStatus(availability: $availability, '
      'currentDefault: $currentDefaultPackage, '
      'apiLevel: $androidApiLevel)';
}
