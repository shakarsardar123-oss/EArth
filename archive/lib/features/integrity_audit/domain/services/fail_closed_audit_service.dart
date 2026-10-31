/// fail_closed_audit_service.dart
/// AURA Assistant – Step 26: Domain service for FAIL-CLOSED invariant auditing.
///
/// Audits all FAIL-CLOSED invariants across Steps 22–25 to ensure:
///   - unknown → denied
///   - error → denied
///   - unavailable → denied
///   - canSkip → shouldAbort (NEVER skip)
///
/// Kurdish Sorani RTL-first: locale='ku'.
library;

import '../models/audit_finding.dart';
import '../models/fail_closed_invariant.dart';

/// Abstract interface for FAIL-CLOSED invariant auditing.
///
/// Implementations check every adapter and repository across
/// Steps 22–25 for FAIL-CLOSED compliance.
abstract class FailClosedAuditService {
  /// Audit all FAIL-CLOSED invariants for a given step.
  ///
  /// Returns [AuditFinding]s for any violations found.
  /// FAIL-CLOSED: if audit itself fails → returns critical finding.
  Future<List<AuditFinding>> auditStep({
    required String step,
    required String locale,
  });

  /// Audit all FAIL-CLOSED invariants across all Steps 22–25.
  ///
  /// Returns [AuditFinding]s for any violations found.
  Future<List<AuditFinding>> auditAllSteps({
    required String locale,
  });

  /// Get the full inventory of FAIL-CLOSED invariants for a step.
  ///
  /// Returns all [FailClosedInvariant]s that apply to [step].
  Future<List<FailClosedInvariant>> getInvariants({
    required String step,
  });

  /// Verify a single invariant is upheld.
  ///
  /// Returns true if the invariant is verified, false otherwise.
  /// FAIL-CLOSED: if verification fails → false.
  Future<bool> verifyInvariant({
    required FailClosedInvariant invariant,
    required String locale,
  });

  /// Get the FAIL-CLOSED compliance score for a step (0.0 to 1.0).
  ///
  /// FAIL-CLOSED: 1.0 only if all invariants are verified.
  Future<double> complianceScore({
    required String step,
    required String locale,
  });
}
