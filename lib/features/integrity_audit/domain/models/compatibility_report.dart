/// compatibility_report.dart
/// AURA Assistant – Step 26: Domain model for cross-adapter compatibility reports.
///
/// Aggregates all [IntegrityVerdict]s for a pair of steps into a single report.
/// FAIL-CLOSED: any drift → report.isCompatible = false.
library;

import 'integrity_verdict.dart';

/// Aggregated compatibility report for a pair of steps.
///
/// Contains every [IntegrityVerdict] produced by comparing all
/// interfaces between [referenceStep] and [comparedStep].
///
/// FAIL-CLOSED: if any verdict is drift, [isCompatible] is false.
class CompatibilityReport {
  /// The reference (canonical) step.
  final String referenceStep;

  /// The compared step.
  final String comparedStep;

  /// All individual verdicts.
  final List<IntegrityVerdict> verdicts;

  /// When this report was generated (ISO 8601 string).
  final String generatedAt;

  /// FAIL-CLOSED: treat unknown/null as incompatible.
  final bool failClosed;

  const CompatibilityReport({
    required this.referenceStep,
    required this.comparedStep,
    required this.verdicts,
    required this.generatedAt,
    this.failClosed = true,
  });

  /// FAIL-CLOSED: report is compatible ONLY if every verdict is compatible.
  /// A single incompatible/missing verdict makes the whole report incompatible.
  bool get isCompatible =>
      failClosed
          ? verdicts.every((v) => v.isClean)
          : verdicts.isNotEmpty && verdicts.every((v) => v.isClean);

  /// Number of drifts found (incompatible + missing verdicts).
  int get driftCount => verdicts.where((v) => v.isDrift).length;

  /// Number of clean (compatible) verdicts.
  int get cleanCount => verdicts.where((v) => v.isClean).length;

  /// Total verdicts in this report.
  int get totalCount => verdicts.length;

  /// All incompatible verdicts.
  List<IntegrityVerdict> get incompatibilities =>
      verdicts.where((v) => v.status == IntegrityStatus.incompatible).toList();

  /// All missing verdicts.
  List<IntegrityVerdict> get missingInterfaces =>
      verdicts.where((v) => v.status == IntegrityStatus.missing).toList();

  /// Critical-severity drifts only.
  List<IntegrityVerdict> get criticalDrifts =>
      verdicts.where((v) => v.severity == IntegritySeverity.critical).toList();

  /// High-severity drifts only.
  List<IntegrityVerdict> get highDrifts =>
      verdicts.where((v) => v.severity == IntegritySeverity.high).toList();

  /// Verdicts filtered by interface name.
  List<IntegrityVerdict> verdictsFor(String interfaceName) =>
      verdicts.where((v) => v.interfaceName == interfaceName).toList();

  /// Verdicts filtered by member name.
  List<IntegrityVerdict> verdictsForMember(String memberName) =>
      verdicts.where((v) => v.memberName == memberName).toList();

  /// FAIL-CLOSED factory: empty/null verdicts → incompatible report.
  factory CompatibilityReport.failClosed({
    required String referenceStep,
    required String comparedStep,
    required String generatedAt,
    List<IntegrityVerdict>? verdicts,
  }) {
    final safeVerdicts = verdicts ?? [];
    if (safeVerdicts.isEmpty) {
      return CompatibilityReport(
        referenceStep: referenceStep,
        comparedStep: comparedStep,
        verdicts: [
          IntegrityVerdict.failClosed(
            referenceStep: referenceStep,
            comparedStep: comparedStep,
          ),
        ],
        generatedAt: generatedAt,
        failClosed: true,
      );
    }
    return CompatibilityReport(
      referenceStep: referenceStep,
      comparedStep: comparedStep,
      verdicts: safeVerdicts,
      generatedAt: generatedAt,
      failClosed: true,
    );
  }

  @override
  String toString() =>
      'CompatibilityReport($referenceStep vs $comparedStep: '
      '${driftCount} drifts, ${cleanCount} clean, compatible=$isCompatible)';
}
