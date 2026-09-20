/// confirmation_repository.dart
/// AURA Assistant – Step 25: Adapter target for Step 23 ConfirmationRepository
///
/// Exact signature match from Step 23.
/// FAIL-CLOSED: ConfirmationMode.denyAll → never execute.
library;

/// Confirmation mode (matches Step 23).
enum ConfirmationMode {
  autoApprove,
  requireConfirmation,
  denyAll,
  ;

  /// FAIL-CLOSED: unknown name → denyAll.
  static ConfirmationMode fromName(String name) {
    return ConfirmationMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ConfirmationMode.denyAll,
    );
  }
}

/// Represents a confirmation verdict.
class ConfirmationVerdict {
  final bool obtained;
  final ConfirmationMode mode;
  final String? reason;

  const ConfirmationVerdict({
    this.obtained = false,
    this.mode = ConfirmationMode.denyAll,
    this.reason,
  });

  /// FAIL-CLOSED: denyAll → never execute.
  bool get isAllowed => obtained && mode != ConfirmationMode.denyAll;
}

/// Abstract repository matching Step 23's ConfirmationRepository.
/// checkAndObtain({toolId, riskLevel, userRequest}) → ConfirmationVerdict
/// isAvailable() → bool
abstract class ConfirmationRepository {
  Future<ConfirmationVerdict> checkAndObtain({
    required String toolId,
    required String riskLevel,
    required String userRequest,
  });
  bool isAvailable();
}
