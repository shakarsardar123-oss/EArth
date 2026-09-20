/// integrity_audit_orchestrator.dart
/// AURA Assistant – Step 26: Application-layer orchestrator for the integrity audit.
///
/// Coordinates all audit operations across Steps 22–25:
///   1. Cross-adapter interface verification
///   2. FAIL-CLOSED invariant regression testing
///   3. Localization completeness QA
///   4. Compatibility report generation
///
/// FAIL-CLOSED: any sub-audit failure → overall verdict = denied.
/// Kurdish Sorani RTL-first: locale='ku'.
library;

import '../domain/models/integrity_verdict.dart';
import '../domain/models/compatibility_report.dart';
import '../domain/models/audit_finding.dart';
import '../domain/models/localization_gap.dart';
import '../domain/services/integrity_verification_service.dart';
import '../domain/services/step_compatibility_service.dart';
import '../domain/services/fail_closed_audit_service.dart';
import '../domain/services/localization_completeness_service.dart';

/// Result of a full integrity audit across Steps 22–25.
class IntegrityAuditResult {
  final IntegrityVerdict overallVerdict;
  final CompatibilityReport compatibilityReport;
  final List<AuditFinding> failClosedFindings;
  final List<LocalizationGap> localizationGaps;
  final List<IntegrityVerdict> stepVerdicts;
  final DateTime auditedAt;
  final String locale;

  const IntegrityAuditResult({
    required this.overallVerdict,
    required this.compatibilityReport,
    required this.failClosedFindings,
    required this.localizationGaps,
    required this.stepVerdicts,
    required this.auditedAt,
    required this.locale,
  });

  /// FAIL-CLOSED factory: if anything is unknown → denied.
  factory IntegrityAuditResult.failClosed({
    required CompatibilityReport report,
    required List<AuditFinding> findings,
    required List<LocalizationGap> gaps,
    required List<IntegrityVerdict> verdicts,
    required String locale,
  }) {
    final anyViolation = findings.any(
      (f) => f.severity == AuditSeverity.critical,
    );
    final anyIncompatible = verdicts.any(
      (v) => v.status == IntegrityStatus.denied,
    );
    final overall = (anyViolation || anyIncompatible)
        ? IntegrityVerdict.failClosed(
            step: 'all',
            reason: 'FAIL-CLOSED: critical finding or denied verdict detected',
            locale: locale,
          )
        : IntegrityVerdict.compatible(
            step: 'all',
            locale: locale,
          );

    return IntegrityAuditResult(
      overallVerdict: overall,
      compatibilityReport: report,
      failClosedFindings: findings,
      localizationGaps: gaps,
      stepVerdicts: verdicts,
      auditedAt: DateTime.now(),
      locale: locale,
    );
  }
}

/// Abstract orchestrator for the full integrity audit pipeline.
///
/// Coordinates:
///   - [IntegrityVerificationService] for cross-adapter checks
///   - [FailClosedAuditService] for FAIL-CLOSED invariant auditing
///   - [LocalizationCompletenessService] for localization QA
///   - [StepCompatibilityService] for compatibility reporting
abstract class IntegrityAuditOrchestrator {
  /// Run the complete integrity audit pipeline.
  ///
  /// FAIL-CLOSED: any sub-audit failure → overall denied.
  Future<IntegrityAuditResult> runFullAudit({
    required String locale,
  });

  /// Run the cross-adapter interface verification only.
  Future<CompatibilityReport> runCrossAdapterVerification({
    required String locale,
  });

  /// Run the FAIL-CLOSED invariant audit only.
  Future<List<AuditFinding>> runFailClosedAudit({
    required String locale,
  });

  /// Run the localization completeness QA only.
  Future<List<LocalizationGap>> runLocalizationQa({
    required String locale,
  });

  /// Get the audit status for a specific step.
  ///
  /// FAIL-CLOSED: if step unknown → denied.
  Future<IntegrityVerdict> getStepVerdict({
    required String step,
    required String locale,
  });
}
