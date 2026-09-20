/// audit_finding.dart
/// AURA Assistant – Step 26: Domain model for individual audit findings.
///
/// Each finding represents one discovered issue from the QA audit.
/// FAIL-CLOSED: severity never below [AuditSeverity.medium] for any drift.
library;


/// A single audit finding from the Step 26 QA process.
///
/// Findings are classified by category, severity, and the step pair
/// where the issue was discovered.
class AuditFinding {
  /// Unique finding identifier.
  final String findingId;

  /// The step where the issue originates.
  final String sourceStep;

  /// The step where the impact is observed (may be same as sourceStep).
  final String impactStep;

  /// Category of the finding.
  final AuditCategory category;

  /// Severity level.
  final AuditSeverity severity;

  /// Short human-readable title.
  final String title;

  /// Detailed description of the finding.
  final String description;

  /// The file path where the issue was found (relative to step root).
  final String filePath;

  /// The specific member (method/field/class) involved.
  final String member;

  /// Expected signature/behavior (from reference step).
  final String expected;

  /// Actual signature/behavior (from compared step).
  final String actual;

  /// Whether this finding has been documented in the final report.
  final bool documented;

  const AuditFinding({
    required this.findingId,
    required this.sourceStep,
    required this.impactStep,
    required this.category,
    required this.severity,
    required this.title,
    required this.description,
    required this.filePath,
    required this.member,
    required this.expected,
    required this.actual,
    this.documented = false,
  });

  /// Factory for interface drift findings.
  factory AuditFinding.interfaceDrift({
    required String findingId,
    required String sourceStep,
    required String impactStep,
    required String title,
    required String description,
    required String filePath,
    required String member,
    required String expected,
    required String actual,
    AuditSeverity severity = AuditSeverity.high,
  }) {
    return AuditFinding(
      findingId: findingId,
      sourceStep: sourceStep,
      impactStep: impactStep,
      category: AuditCategory.interfaceDrift,
      severity: severity,
      title: title,
      description: description,
      filePath: filePath,
      member: member,
      expected: expected,
      actual: actual,
    );
  }

  /// Factory for FAIL-CLOSED violation findings.
  factory AuditFinding.failClosedViolation({
    required String findingId,
    required String sourceStep,
    required String impactStep,
    required String title,
    required String description,
    required String filePath,
    required String member,
    required String expected,
    required String actual,
  }) {
    return AuditFinding(
      findingId: findingId,
      sourceStep: sourceStep,
      impactStep: impactStep,
      category: AuditCategory.failClosedViolation,
      severity: AuditSeverity.critical,
      title: title,
      description: description,
      filePath: filePath,
      member: member,
      expected: expected,
      actual: actual,
    );
  }

  /// Factory for localization gap findings.
  factory AuditFinding.localizationGap({
    required String findingId,
    required String sourceStep,
    required String impactStep,
    required String title,
    required String description,
    required String filePath,
    required String member,
    required String expected,
    required String actual,
    AuditSeverity severity = AuditSeverity.medium,
  }) {
    return AuditFinding(
      findingId: findingId,
      sourceStep: sourceStep,
      impactStep: impactStep,
      category: AuditCategory.localizationGap,
      severity: severity,
      title: title,
      description: description,
      filePath: filePath,
      member: member,
      expected: expected,
      actual: actual,
    );
  }

  /// Factory for test gap findings (missing test coverage).
  factory AuditFinding.testGap({
    required String findingId,
    required String sourceStep,
    required String impactStep,
    required String title,
    required String description,
    required String filePath,
    required String member,
    required String expected,
    required String actual,
  }) {
    return AuditFinding(
      findingId: findingId,
      sourceStep: sourceStep,
      impactStep: impactStep,
      category: AuditCategory.testGap,
      severity: AuditSeverity.high,
      title: title,
      description: description,
      filePath: filePath,
      member: member,
      expected: expected,
      actual: actual,
    );
  }

  /// Mark this finding as documented.
  AuditFinding markDocumented() => AuditFinding(
        findingId: findingId,
        sourceStep: sourceStep,
        impactStep: impactStep,
        category: category,
        severity: severity,
        title: title,
        description: description,
        filePath: filePath,
        member: member,
        expected: expected,
        actual: actual,
        documented: true,
      );

  /// Whether this finding is critical-severity.
  bool get isCritical => severity == AuditSeverity.critical;

  /// Whether this finding is about interface drift.
  bool get isInterfaceDrift => category == AuditCategory.interfaceDrift;

  @override
  String toString() =>
      'AuditFinding($findingId: $category, $severity, $title)';
}

/// Categories of audit findings.
enum AuditCategory {
  /// Interface signature mismatch between steps.
  interfaceDrift,

  /// FAIL-CLOSED invariant violation (e.g., canSkip allowed, unknown not denied).
  failClosedViolation,

  /// Missing or incomplete localization (Kurdish Sorani keys).
  localizationGap,

  /// Missing test coverage for a step or feature.
  testGap,

  /// Structural issue (missing file, empty directory, broken barrel export).
  structuralIssue,
}

/// Severity levels for audit findings.
enum AuditSeverity {
  /// Informational only.
  info,

  /// Medium – should be addressed but not blocking.
  medium,

  /// High – should be addressed before release.
  high,

  /// Critical – must be addressed immediately (FAIL-CLOSED violation, data leak).
  critical,
}
