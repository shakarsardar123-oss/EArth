/// integrity_verdict.dart
/// AURA Assistant – Step 26: Domain model for integrity verification verdicts.
///
/// Represents the outcome of an integrity check between two steps.
/// FAIL-CLOSED: unknown → incompatible, error → incompatible, missing → incompatible.
library;

/// Result of comparing interface signatures across steps.
///
/// Every comparison yields one of these verdicts:
/// - [compatible]  – signatures match exactly (same names, types, params).
/// - [incompatible] – signatures differ (type mismatch, missing method, extra method,
///                     different param names/optionality, different field sets).
/// - [missing]      – the interface exists in one step but not the other.
///
/// FAIL-CLOSED defaults:
///   - Any null/empty check → [incompatible]
///   - Any parse error → [incompatible]
///   - Missing method → [incompatible] (NEVER silently pass)
class IntegrityVerdict {
  /// The step that defines the canonical (reference) interface.
  final String referenceStep;

  /// The step whose interface is being compared.
  final String comparedStep;

  /// The fully qualified interface name (e.g. 'AuditRepository').
  final String interfaceName;

  /// The specific member being checked (method/field/constructor name).
  final String memberName;

  /// The verdict category.
  final IntegrityStatus status;

  /// Human-readable description of the drift (if any).
  /// Empty string when [status] is [IntegrityStatus.compatible].
  final String driftDescription;

  /// Severity of the drift (informational only; all drifts are recorded).
  final IntegritySeverity severity;

  const IntegrityVerdict({
    required this.referenceStep,
    required this.comparedStep,
    required this.interfaceName,
    required this.memberName,
    required this.status,
    this.driftDescription = '',
    this.severity = IntegritySeverity.high,
  });

  /// Compatible verdict – no drift detected.
  factory IntegrityVerdict.compatible({
    required String referenceStep,
    required String comparedStep,
    required String interfaceName,
    required String memberName,
  }) {
    return IntegrityVerdict(
      referenceStep: referenceStep,
      comparedStep: comparedStep,
      interfaceName: interfaceName,
      memberName: memberName,
      status: IntegrityStatus.compatible,
      driftDescription: '',
      severity: IntegritySeverity.none,
    );
  }

  /// Incompatible verdict – drift detected (FAIL-CLOSED default for any mismatch).
  factory IntegrityVerdict.incompatible({
    required String referenceStep,
    required String comparedStep,
    required String interfaceName,
    required String memberName,
    required String driftDescription,
    IntegritySeverity severity = IntegritySeverity.high,
  }) {
    return IntegrityVerdict(
      referenceStep: referenceStep,
      comparedStep: comparedStep,
      interfaceName: interfaceName,
      memberName: memberName,
      status: IntegrityStatus.incompatible,
      driftDescription: driftDescription,
      severity: severity,
    );
  }

  /// Missing verdict – interface exists in reference but not in compared step.
  factory IntegrityVerdict.missing({
    required String referenceStep,
    required String comparedStep,
    required String interfaceName,
    required String memberName,
    required String driftDescription,
  }) {
    return IntegrityVerdict(
      referenceStep: referenceStep,
      comparedStep: comparedStep,
      interfaceName: interfaceName,
      memberName: memberName,
      status: IntegrityStatus.missing,
      driftDescription: driftDescription,
      severity: IntegritySeverity.critical,
    );
  }

  /// FAIL-CLOSED: any null or empty input → incompatible.
  factory IntegrityVerdict.failClosed({
    required String referenceStep,
    required String comparedStep,
    String? interfaceName,
    String? memberName,
    String? driftDescription,
  }) {
    return IntegrityVerdict(
      referenceStep: referenceStep,
      comparedStep: comparedStep,
      interfaceName: interfaceName ?? '<unknown>',
      memberName: memberName ?? '<unknown>',
      status: IntegrityStatus.incompatible,
      driftDescription: driftDescription ?? 'FAIL-CLOSED: null/empty input treated as incompatible',
      severity: IntegritySeverity.critical,
    );
  }

  /// Whether this verdict represents a problem (incompatible or missing).
  bool get isDrift => status == IntegrityStatus.incompatible || status == IntegrityStatus.missing;

  /// Whether this verdict is clean (compatible).
  bool get isClean => status == IntegrityStatus.compatible;

  @override
  String toString() =>
      'IntegrityVerdict($referenceStep vs $comparedStep, '
      '$interfaceName.$memberName: $status, $driftDescription)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntegrityVerdict &&
          referenceStep == other.referenceStep &&
          comparedStep == other.comparedStep &&
          interfaceName == other.interfaceName &&
          memberName == other.memberName &&
          status == other.status;

  @override
  int get hashCode => Object.hash(referenceStep, comparedStep, interfaceName, memberName, status);
}

/// Status categories for interface comparison results.
enum IntegrityStatus {
  /// Signatures match exactly.
  compatible,

  /// Signatures differ (type mismatch, param drift, etc.).
  incompatible,

  /// Interface/member exists in one step but not the other.
  missing,
}

/// Severity levels for interface drift findings.
enum IntegritySeverity {
  /// No drift – clean.
  none,

  /// Minor drift (e.g., optional param default differs).
  low,

  /// Significant drift (e.g., return type mismatch, param name mismatch).
  high,

  /// Critical drift (e.g., missing interface, completely different model structure).
  critical,
}
