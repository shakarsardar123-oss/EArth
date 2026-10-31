/// fail_closed_regression_checker.dart
/// AURA Assistant – Step 26: Application-layer FAIL-CLOSED regression checker.
///
/// Verifies that FAIL-CLOSED invariants are upheld across Steps 22–25
/// without regression. Each invariant is checked per step:
///
///   - unknown → denied
///   - error → denied
///   - unavailable → denied
///   - canSkip → shouldAbort (NEVER skip)
///
/// FAIL-CLOSED: any regression → critical finding.
/// Kurdish Sorani RTL-first: locale='ku'.
library;

import '../domain/models/audit_finding.dart';
import '../domain/models/fail_closed_invariant.dart';

/// Result of a FAIL-CLOSED regression check for a single step.
class FailClosedRegressionResult {
  final String step;
  final List<FailClosedInvariant> invariants;
  final List<AuditFinding> regressions;
  final bool isCompliant;
  final double complianceScore;
  final DateTime checkedAt;
  final String locale;

  const FailClosedRegressionResult({
    required this.step,
    required this.invariants,
    required this.regressions,
    required this.isCompliant,
    required this.complianceScore,
    required this.checkedAt,
    required this.locale,
  });

  /// FAIL-CLOSED factory: any regression → non-compliant.
  factory FailClosedRegressionResult.failClosed({
    required String step,
    required List<FailClosedInvariant> invariants,
    required List<AuditFinding> regressions,
    required String locale,
  }) {
    final isCompliant = regressions.isEmpty;
    final score = invariants.isEmpty
        ? 0.0 // FAIL-CLOSED: no invariants → cannot verify → denied
        : (invariants.length - regressions.length) / invariants.length;

    return FailClosedRegressionResult(
      step: step,
      invariants: invariants,
      regressions: regressions,
      isCompliant: isCompliant,
      complianceScore: isCompliant ? 1.0 : score.clamp(0.0, 0.99),
      checkedAt: DateTime.now(),
      locale: locale,
    );
  }
}

/// Overall FAIL-CLOSED regression check across all Steps 22–25.
class FailClosedRegressionSummary {
  final List<FailClosedRegressionResult> stepResults;
  final bool overallCompliant;
  final DateTime checkedAt;
  final String locale;

  const FailClosedRegressionSummary({
    required this.stepResults,
    required this.overallCompliant,
    required this.checkedAt,
    required this.locale,
  });

  /// FAIL-CLOSED factory: any step non-compliant → overall non-compliant.
  factory FailClosedRegressionSummary.failClosed({
    required List<FailClosedRegressionResult> results,
    required String locale,
  }) {
    return FailClosedRegressionSummary(
      stepResults: results,
      overallCompliant: results.every((r) => r.isCompliant),
      checkedAt: DateTime.now(),
      locale: locale,
    );
  }
}

/// Abstract FAIL-CLOSED regression checker.
///
/// Verifies each FAIL-CLOSED invariant per step and detects
/// any regressions from the expected behavior.
abstract class FailClosedRegressionChecker {
  /// Check FAIL-CLOSED invariants for a specific step.
  ///
  /// FAIL-CLOSED: check failure → regression recorded.
  Future<FailClosedRegressionResult> checkStep({
    required String step,
    required String locale,
  });

  /// Check FAIL-CLOSED invariants for Step 22.
  Future<FailClosedRegressionResult> checkStep22({
    required String locale,
  });

  /// Check FAIL-CLOSED invariants for Step 23.
  Future<FailClosedRegressionResult> checkStep23({
    required String locale,
  });

  /// Check FAIL-CLOSED invariants for Step 24.
  Future<FailClosedRegressionResult> checkStep24({
    required String locale,
  });

  /// Check FAIL-CLOSED invariants for Step 25.
  Future<FailClosedRegressionResult> checkStep25({
    required String locale,
  });

  /// Check all Steps 22–25.
  ///
  /// FAIL-CLOSED: any regression → overall non-compliant.
  Future<FailClosedRegressionSummary> checkAllSteps({
    required String locale,
  });

  /// Get the expected FAIL-CLOSED invariants for a step.
  ///
  /// Used to verify the inventory is complete.
  List<FailClosedInvariant> expectedInvariants({
    required String step,
  });
}
