/// Step 24 — Trigger Authorization Repository Interface
///
/// Security gate for trigger requests.
/// FAIL-CLOSED: unknown → DENY, invalid → DENY, unavailable → DENY,
/// security failure → DENY, permission failure → DENY,
/// unexpected exception → DENY.
/// Never silently authorize an unknown or invalid trigger.

import '../entities/trigger_request.dart';
import '../value_objects/trigger_type.dart';

class TriggerAuthorizationVerdict {
  final bool authorized;
  final String? reason;
  final String? policyId;

  const TriggerAuthorizationVerdict({
    this.authorized = false,
    this.reason,
    this.policyId,
  });

  /// FAIL-CLOSED: denied verdict.
  factory TriggerAuthorizationVerdict.denied({
    String? reason,
    String? policyId,
  }) =>
      TriggerAuthorizationVerdict(
        authorized: false,
        reason: reason,
        policyId: policyId,
      );

  /// Authorized verdict — only after all checks pass.
  factory TriggerAuthorizationVerdict.authorized({
    String? policyId,
  }) =>
      TriggerAuthorizationVerdict(
        authorized: true,
        policyId: policyId,
      );
}

abstract class TriggerAuthorizationRepository {
  /// Authorize a trigger request against security policy.
  /// FAIL-CLOSED: unknown/invalid triggers always return denied.
  /// Returns TriggerAuthorizationVerdict — never throws.
  Future<TriggerAuthorizationVerdict> authorize(TriggerRequest request);

  /// Check if the authorization subsystem is available.
  Future<bool> isAvailable();

  /// Check if a specific trigger type is permitted by policy.
  /// FAIL-CLOSED: unknown types → denied.
  Future<bool> isTriggerTypePermitted(TriggerType type);
}
