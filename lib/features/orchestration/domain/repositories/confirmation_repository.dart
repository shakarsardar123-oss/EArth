/// Step 23 — Confirmation Repository Interface
///
/// Contract for the Step 20 Confirmation adapter.
/// FAIL-CLOSED: unknown → denied. ConfirmationMode.denyAll → never execute.
/// Never silently approve a denied confirmation.

abstract class ConfirmationRepository {
  /// Check if confirmation is required and obtain it.
  /// Returns ConfirmationVerdict. Default/unknown = denied.
  Future<ConfirmationVerdict> checkAndObtain({
    required String toolId,
    required String riskLevel,
    required String userRequest,
  });

  /// Whether the confirmation subsystem is available.
  Future<bool> isAvailable();
}

/// Confirmation verdict — FAIL-CLOSED by default.
class ConfirmationVerdict {
  final bool obtained;
  final String? reason;
  final ConfirmationMode mode;

  const ConfirmationVerdict({
    this.obtained = false,
    this.reason,
    this.mode = ConfirmationMode.denyAll,
  });

  factory ConfirmationVerdict.denied({String? reason}) =>
      ConfirmationVerdict(obtained: false, reason: reason, mode: ConfirmationMode.denyAll);

    // AUTO_APPROVE_WARNING: Auto-approve bypasses user confirmation. Dev/test only. Production MUST require explicit approval.
  factory ConfirmationVerdict.granted({ConfirmationMode mode = ConfirmationMode.autoApprove}) =>
      ConfirmationVerdict(obtained: true, mode: mode);
}

/// Confirmation modes — per Step 20 contract.
/// denyAll is the correct name (not autoDeny).
enum ConfirmationMode {
  autoApprove, // low risk → may auto-approve
  requireConfirmation, // medium/high risk → explicit confirmation
  denyAll, // never execute — FAIL-CLOSED
  ;
}
