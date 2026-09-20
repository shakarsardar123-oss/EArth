/// trigger_repository.dart
/// AURA Assistant – Step 25: Adapter target for Step 24 TriggerAuthorizationRepository
///
/// Exact signature match from Step 24.
/// FAIL-CLOSED: TriggerType.unknown → never authorized.
library;

/// Trigger type (matches Step 24).
enum TriggerType {
  voiceCommand,
  schedule,
  event,
  proximity,
  gesture,
  unknown,
  ;

  /// FAIL-CLOSED: unknown name → unknown.
  static TriggerType fromName(String name) {
    return TriggerType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TriggerType.unknown,
    );
  }
}

/// Trigger authorization verdict (matches Step 24).
class TriggerAuthorizationVerdict {
  final bool authorized;
  final String? reason;
  final TriggerType? triggerType;

  const TriggerAuthorizationVerdict({
    this.authorized = false,
    this.reason,
    this.triggerType,
  });

  /// FAIL-CLOSED: default is denied.
  factory TriggerAuthorizationVerdict.denied({String? reason}) =>
      TriggerAuthorizationVerdict(authorized: false, reason: reason);

  factory TriggerAuthorizationVerdict.allowed({
    required TriggerType type,
    String? reason,
  }) =>
      TriggerAuthorizationVerdict(
        authorized: true,
        triggerType: type,
        reason: reason,
      );
}

/// Trigger request (matches Step 24).
class TriggerRequest {
  final String id;
  final TriggerType type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  const TriggerRequest({
    required this.id,
    required this.type,
    this.payload = const {},
    required this.timestamp,
  });
}

/// Abstract repository matching Step 24's TriggerAuthorizationRepository.
/// authorize(request) → TriggerAuthorizationVerdict
/// isAvailable() → bool
/// isTriggerTypePermitted(type) → bool
abstract class TriggerRepository {
  Future<TriggerAuthorizationVerdict> authorize(TriggerRequest request);
  bool isAvailable();
  bool isTriggerTypePermitted(TriggerType type);
}
