/// Step 26 — Integrity Audit Orchestrator
///
/// Orchestrates cross-step integrity audits to detect API drift.
///
/// AUDIT FIX — Bug #9a:
///   Fixed phantom API usage:
///   - `IntegrityStatus.denied` → `IntegrityStatus.incompatible`
///     (no 'denied' member exists; only {compatible, incompatible, missing})
///   - `IntegrityVerdict.failClosed(step:, reason:, locale:)` →
///     `IntegrityVerdict.failClosed(referenceStep:, comparedStep:,
///       interfaceName:, memberName:, driftDescription:)`
///     (failClosed takes step references and interface details, not reason/locale)
///   - `IntegrityVerdict.compatible(step:, locale:)` →
///     `IntegrityVerdict.compatible(referenceStep:, comparedStep:,
///       interfaceName:, memberName:)`
///     (compatible takes step references and interface details, not locale)
///   All phantom constructors replaced with REAL constructors from domain models.
///   FAIL-CLOSED: errors produce incompatible verdicts, not 'denied'.

import '../domain/models/integrity_status.dart';
import '../domain/models/integrity_verdict.dart';
import '../domain/models/integrity_severity.dart';
import 'cross_adapter_checker.dart';

class IntegrityAuditOrchestrator {
  final CrossAdapterChecker _checker;

  IntegrityAuditOrchestrator({required CrossAdapterChecker checker})
      : _checker = checker;

  /// Run a full integrity audit across all steps.
  /// Returns a list of verdicts. FAIL-CLOSED: any error → incompatible verdict.
  Future<List<IntegrityVerdict>> runAudit() async {
    final verdicts = <IntegrityVerdict>[];

    try {
      final stepResults = await _checker.checkAllAdapters();

      for (final result in stepResults) {
        if (result.isCompatible) {
          verdicts.add(IntegrityVerdict.compatible(
            referenceStep: result.referenceStep,
            comparedStep: result.comparedStep,
            interfaceName: result.interfaceName,
            memberName: result.memberName,
          ));
        } else if (result.isMissing) {
          verdicts.add(IntegrityVerdict.missing(
            referenceStep: result.referenceStep,
            comparedStep: result.comparedStep,
            interfaceName: result.interfaceName,
            memberName: result.memberName,
            driftDescription: result.driftDescription ?? 'Member not found',
          ));
        } else {
          // Drift detected or any other issue → incompatible
          verdicts.add(IntegrityVerdict.incompatible(
            referenceStep: result.referenceStep,
            comparedStep: result.comparedStep,
            interfaceName: result.interfaceName,
            memberName: result.memberName,
            driftDescription: result.driftDescription ?? 'Interface drift detected',
            severity: result.severity ?? IntegritySeverity.high,
          ));
        }
      }
    } catch (e) {
      // FAIL-CLOSED: audit error → fail-closed verdict
      verdicts.add(IntegrityVerdict.failClosed(
        referenceStep: 'audit',
        comparedStep: 'unknown',
        interfaceName: null,
        memberName: null,
        driftDescription: 'Audit failed with error: $e',
      ));
    }

    return verdicts;
  }

  /// Audit a specific step pair. FAIL-CLOSED on error.
  Future<IntegrityVerdict> auditStepPair({
    required String referenceStep,
    required String comparedStep,
    required String interfaceName,
    required String memberName,
  }) async {
    try {
      final result = await _checker.checkAdapter(
        referenceStep: referenceStep,
        comparedStep: comparedStep,
        interfaceName: interfaceName,
        memberName: memberName,
      );

      if (result.isCompatible) {
        return IntegrityVerdict.compatible(
          referenceStep: referenceStep,
          comparedStep: comparedStep,
          interfaceName: interfaceName,
          memberName: memberName,
        );
      } else if (result.isMissing) {
        return IntegrityVerdict.missing(
          referenceStep: referenceStep,
          comparedStep: comparedStep,
          interfaceName: interfaceName,
          memberName: memberName,
          driftDescription: result.driftDescription ?? 'Member not found',
        );
      } else {
        return IntegrityVerdict.incompatible(
          referenceStep: referenceStep,
          comparedStep: comparedStep,
          interfaceName: interfaceName,
          memberName: memberName,
          driftDescription: result.driftDescription ?? 'Interface drift detected',
          severity: result.severity ?? IntegritySeverity.high,
        );
      }
    } catch (e) {
      // FAIL-CLOSED: error → fail-closed verdict
      return IntegrityVerdict.failClosed(
        referenceStep: referenceStep,
        comparedStep: comparedStep,
        interfaceName: interfaceName,
        memberName: memberName,
        driftDescription: 'Audit check failed with error: $e',
      );
    }
  }

  /// Check overall integrity status from verdicts.
  /// FAIL-CLOSED: any non-compatible verdict → incompatible (not 'denied').
  IntegrityStatus overallStatus(List<IntegrityVerdict> verdicts) {
    if (verdicts.isEmpty) {
      // No verdicts → cannot confirm integrity → fail-closed
      return IntegrityStatus.incompatible;
    }
    final allCompatible = verdicts.every(
      (v) => v.status == IntegrityStatus.compatible,
    );
    if (allCompatible) {
      return IntegrityStatus.compatible;
    }
    // Any incompatible or missing → incompatible overall
    return IntegrityStatus.incompatible;
  }
}
