/// cross_adapter_checker.dart
/// AURA Assistant – Step 26: Application-layer cross-adapter compatibility checker.
///
/// Verifies interface consistency between Step 23 (Orchestration) and
/// Step 25 (Advanced Agent), with additional checks against Step 22
/// (Tool Execution) and Step 24 (Trigger Integration).
///
/// Documented interface drift bugs (#1–#12) are checked here.
///
/// FAIL-CLOSED: any mismatch → drift recorded → incompatibility flagged.
/// Kurdish Sorani RTL-first: locale='ku'.
library;

import '../domain/models/integrity_verdict.dart';

/// Describes a specific interface drift between two steps.
class InterfaceDrift {
  final String driftId;
  final String sourceStep;
  final String targetStep;
  final String className;
  final String methodName;
  final String sourceSignature;
  final String targetSignature;
  final IntegritySeverity severity;
  final String description;

  const InterfaceDrift({
    required this.driftId,
    required this.sourceStep,
    required this.targetStep,
    required this.className,
    required this.methodName,
    required this.sourceSignature,
    required this.targetSignature,
    required this.severity,
    required this.description,
  });
}

/// Result of cross-adapter checking between two steps.
class CrossAdapterCheckResult {
  final String sourceStep;
  final String targetStep;
  final List<InterfaceDrift> drifts;
  final IntegrityVerdict verdict;
  final DateTime checkedAt;
  final String locale;

  const CrossAdapterCheckResult({
    required this.sourceStep,
    required this.targetStep,
    required this.drifts,
    required this.verdict,
    required this.checkedAt,
    required this.locale,
  });

  /// FAIL-CLOSED factory: any drift → denied.
  factory CrossAdapterCheckResult.failClosed({
    required String sourceStep,
    required String targetStep,
    required List<InterfaceDrift> drifts,
    required String locale,
  }) {
    final hasCritical = drifts.any(
      (d) => d.severity == IntegritySeverity.critical,
    );
    final verdict = hasCritical
        ? IntegrityVerdict.failClosed(
            step: '${sourceStep}_vs_$targetStep',
            reason: 'FAIL-CLOSED: critical interface drift detected',
            locale: locale,
          )
        : IntegrityVerdict.driftDetected(
            step: '${sourceStep}_vs_$targetStep',
            driftCount: drifts.length,
            locale: locale,
          );

    return CrossAdapterCheckResult(
      sourceStep: sourceStep,
      targetStep: targetStep,
      drifts: drifts,
      verdict: verdict,
      checkedAt: DateTime.now(),
      locale: locale,
    );
  }
}

/// Abstract cross-adapter compatibility checker.
///
/// Checks all 12 documented interface drift bugs plus any
/// additional drifts discovered during introspection.
abstract class CrossAdapterChecker {
  /// Check Step 23 vs Step 25 interfaces (primary drift check).
  ///
  /// Validates the 12 documented interface drift bugs.
  Future<CrossAdapterCheckResult> checkStep23VsStep25({
    required String locale,
  });

  /// Check Step 22 vs Step 25 interfaces (execution path).
  Future<CrossAdapterCheckResult> checkStep22VsStep25({
    required String locale,
  });

  /// Check Step 24 vs Step 25 interfaces (trigger path).
  Future<CrossAdapterCheckResult> checkStep24VsStep25({
    required String locale,
  });

  /// Run all cross-adapter checks.
  Future<List<CrossAdapterCheckResult>> checkAllPairs({
    required String locale,
  });

  /// Get the documented drift bugs for reference.
  ///
  /// Returns the 12 known interface drifts for verification.
  List<InterfaceDrift> getDocumentedDrifts();

  /// Check a specific interface for drift.
  ///
  /// FAIL-CLOSED: if either side unavailable → drift recorded.
  Future<InterfaceDrift?> checkSpecificInterface({
    required String sourceStep,
    required String targetStep,
    required String className,
    required String methodName,
    required String locale,
  });
}
