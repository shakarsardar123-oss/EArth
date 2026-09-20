/// Step 24 — Trigger Type
///
/// Enumeration of all supported trigger sources.
/// FAIL-CLOSED: unknown trigger types are NEVER authorized.
/// Unknown → DENY per security policy.

enum TriggerType {
  quickSettings,
  assistantLongPress,
  homeLongPress,
  notificationAction,
  inApp,
  unknown,
  ;

  /// Whether this trigger type is recognized and may proceed to authorization.
  /// FAIL-CLOSED: [unknown] is never authorizable.
  bool get isAuthorizable => this != TriggerType.unknown;

  /// FAIL-CLOSED: parse from string, unknown strings → [TriggerType.unknown].
  static TriggerType fromName(String name) {
    return TriggerType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TriggerType.unknown,
    );
  }

  /// Human-readable name for logging (never user-facing).
  String get logLabel => name;
}
