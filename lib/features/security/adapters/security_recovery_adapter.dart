/// security_recovery_adapter.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Adapter bridging Security feature with Step 18 RecoveryCoordinator.
/// Allows security failures to trigger recovery flows and
/// recovery failures to be treated as security events.
///
/// FAIL CLOSED: if recovery itself fails, the original security
/// failure verdict stands (never downgrade a denial).
library;

import 'package:aura_assistant/core/errors/result.dart';
import '../domain/models/security_failure.dart';
import '../domain/models/security_verdict.dart';

/// Recovery failure types relevant to security.
enum SecurityRecoveryType {
  /// Secret scanning recovered after false positive.
  secretScanRecovery,

  /// Redaction error recovered by fallback rule.
  redactionRecovery,

  /// Storage corruption recovered from backup.
  storageCorruptionRecovery,

  /// Permission denial recovered via re-request.
  permissionRecovery,

  /// Audit log recovered after write failure.
  auditRecovery,

  /// Provider privacy failure recovered.
  providerPrivacyRecovery,

  /// Unknown — FAIL CLOSED: treated as critical.
  unknown,
}

/// Result of a recovery attempt within the security context.
class SecurityRecoveryResult {
  /// Whether recovery succeeded.
  final bool succeeded;

  /// The type of recovery that was attempted.
  final SecurityRecoveryType type;

  /// Original security verdict that triggered recovery.
  final SecurityVerdict? originalVerdict;

  /// New verdict after recovery (if succeeded).
  final SecurityVerdict? recoveredVerdict;

  /// Description of the recovery action.
  final String description;

  /// Whether the original denial still stands even after recovery attempt.
  /// FAIL CLOSED: even if recovery itself errors, denial persists.
  final bool denialPersists;

  const SecurityRecoveryResult({
    required this.succeeded,
    required this.type,
    this.originalVerdict,
    this.recoveredVerdict,
    required this.description,
    required this.denialPersists,
  });

  /// FAIL CLOSED: always returns a result where denial persists
  /// if recovery failed.
  factory SecurityRecoveryResult.failed({
    required SecurityRecoveryType type,
    SecurityVerdict? originalVerdict,
    String? cause,
  }) =>
      SecurityRecoveryResult(
        succeeded: false,
        type: type,
        originalVerdict: originalVerdict,
        description: cause ?? 'Recovery failed — original security decision stands',
        denialPersists: true,
      );

  /// Successful recovery — verdict may be upgraded.
  factory SecurityRecoveryResult.succeeded({
    required SecurityRecoveryType type,
    SecurityVerdict? originalVerdict,
    SecurityVerdict? recoveredVerdict,
    required String description,
  }) =>
      SecurityRecoveryResult(
        succeeded: true,
        type: type,
        originalVerdict: originalVerdict,
        recoveredVerdict: recoveredVerdict,
        description: description,
        // Even on success, denial persists if recovered verdict is still denied
        denialPersists: recoveredVerdict?.isDenied ??
            originalVerdict?.isDenied ??
            true, // FAIL CLOSED: default deny
      );
}

/// Abstract adapter for integrating security with recovery.
///
/// Security failures may be recoverable (e.g., false positive
/// secret detection). This adapter bridges the two systems.
abstract class SecurityRecoveryAdapter {
  /// Attempt recovery for a security denial.
  Future<SecurityResult<SecurityRecoveryResult>> attemptRecovery(
    SecurityVerdict deniedVerdict,
    SecurityRecoveryType type, {
    Map<String, dynamic> context = const {},
  });

  /// Check if a specific type of recovery is available.
  bool isRecoveryAvailable(SecurityRecoveryType type);

  /// Get all available recovery types for a given verdict.
  List<SecurityRecoveryType> availableRecoveries(
    SecurityVerdict verdict,
  );

  /// Whether any recovery is possible for a fail-closed denial.
  /// FAIL CLOSED: returns false by default — fail-closed denials
  /// are NOT recoverable.
  bool canRecoverFailClosed(SecurityVerdict verdict);
}
