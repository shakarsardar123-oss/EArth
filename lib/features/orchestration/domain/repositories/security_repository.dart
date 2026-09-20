/// Step 23 — Security Repository Interface
///
/// Contract for the Step 19 Security adapter.
/// FAIL-CLOSED: any security check failure or unavailability → denied.
/// Agent-generated actions are treated exactly like user-originated actions.

abstract class SecurityRepository {
  /// Check if the proposed action is allowed by security policies.
  /// Returns a SecurityVerdict. Default/unknown = denied.
  Future<SecurityVerdict> check(String action, String toolId, String riskLevel);

  /// Check if the security subsystem is available.
  Future<bool> isAvailable();
}

/// Security verdict — FAIL-CLOSED by default.
class SecurityVerdict {
  final bool allowed;
  final String? reason;
  final String? policyId;

  const SecurityVerdict({
    this.allowed = false,
    this.reason,
    this.policyId,
  });

  /// Denied verdict with reason.
  factory SecurityVerdict.denied({String? reason, String? policyId}) =>
      SecurityVerdict(allowed: false, reason: reason, policyId: policyId);

  /// Allowed verdict.
  factory SecurityVerdict.allowed({String? policyId}) =>
      SecurityVerdict(allowed: true, policyId: policyId);
}
