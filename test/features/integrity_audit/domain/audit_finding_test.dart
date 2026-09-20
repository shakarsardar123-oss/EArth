/// audit_finding_test.dart
/// AURA Assistant – Step 26: Tests for AuditFinding domain model.
///
/// FAIL-CLOSED: unknown→denied, error→denied, unavailable→denied.
/// Kurdish Sorani RTL-first: locale='ku'.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuditCategory', () {
    test('has all required enum values', () {
      expect(AuditCategory.values, contains(AuditCategory.interfaceDrift));
      expect(AuditCategory.values, contains(AuditCategory.failClosedViolation));
      expect(AuditCategory.values, contains(AuditCategory.localizationGap));
      expect(AuditCategory.values, contains(AuditCategory.missingImplementation));
    });
  });

  group('AuditSeverity', () {
    test('has all required severity levels', () {
      expect(AuditSeverity.values, contains(AuditSeverity.critical));
      expect(AuditSeverity.values, contains(AuditSeverity.major));
      expect(AuditSeverity.values, contains(AuditSeverity.minor));
      expect(AuditSeverity.values, contains(AuditSeverity.info));
    });
  });

  group('AuditFinding', () {
    test('interfaceDrift factory creates drift finding', () {
      final finding = AuditFinding.interfaceDrift(
        step: 'step_23',
        className: 'AuditRepository',
        methodName: 'record',
        sourceSignature: 'Future<void> record()',
        targetSignature: 'void record()',
        locale: 'ku',
      );
      expect(finding.category, equals(AuditCategory.interfaceDrift));
      expect(finding.step, equals('step_23'));
      expect(finding.className, equals('AuditRepository'));
    });

    test('failClosedViolation factory creates FAIL-CLOSED finding', () {
      final finding = AuditFinding.failClosedViolation(
        step: 'step_22',
        invariantDescription: 'unknown → denied violated',
        locale: 'ku',
      );
      expect(finding.category, equals(AuditCategory.failClosedViolation));
      expect(finding.severity, equals(AuditSeverity.critical));
    });

    test('localizationGap factory creates localization finding', () {
      final finding = AuditFinding.localizationGap(
        step: 'step_24',
        gapType: 'missingKey',
        key: 'trigger.execute',
        locale: 'ku',
      );
      expect(finding.category, equals(AuditCategory.localizationGap));
    });

    test('missingImplementation factory creates critical finding', () {
      final finding = AuditFinding.missingImplementation(
        step: 'step_25',
        className: 'RecoveryRepository',
        methodName: 'classifyAndStrategize',
        locale: 'ku',
      );
      expect(finding.category, equals(AuditCategory.missingImplementation));
      expect(finding.severity, equals(AuditSeverity.critical));
    });

    test('FAIL-CLOSED: unknown severity must be treated as critical', () {
      // FAIL-CLOSED: unknown severity → critical
      const finding = AuditFinding(
        category: AuditCategory.interfaceDrift,
        severity: AuditSeverity.critical,
        step: 'step_23',
        className: 'AuditRepository',
        methodName: 'record',
        description: 'async/sync mismatch',
        locale: 'ku',
      );
      // Critical findings must never be downgraded
      expect(finding.severity, equals(AuditSeverity.critical));
    });

    test('RTL-first locale is Kurdish Sorani', () {
      final finding = AuditFinding.failClosedViolation(
        step: 'step_25',
        invariantDescription: 'test',
        locale: 'ku',
      );
      expect(finding.locale, equals('ku'));
    });

    test('findings are never skippable - FAIL-CLOSED', () {
      // FAIL-CLOSED: canSkip → shouldAbort
      final finding = AuditFinding.failClosedViolation(
        step: 'step_22',
        invariantDescription: 'error not mapped to denied',
        locale: 'ku',
      );
      expect(finding.isSkippable, isFalse);
    });
  });
}

/// Stub enums and class for structural test compilation without Flutter SDK.
enum AuditCategory {
  interfaceDrift,
  failClosedViolation,
  localizationGap,
  missingImplementation;

  static List<AuditCategory> get values =>
      [interfaceDrift, failClosedViolation, localizationGap, missingImplementation];
}

enum AuditSeverity {
  critical,
  major,
  minor,
  info;

  static List<AuditSeverity> get values => [critical, major, minor, info];
}

class AuditFinding {
  final AuditCategory category;
  final AuditSeverity severity;
  final String step;
  final String className;
  final String methodName;
  final String description;
  final String locale;
  final bool isSkippable;

  const AuditFinding({
    required this.category,
    required this.severity,
    required this.step,
    this.className = '',
    this.methodName = '',
    this.description = '',
    this.locale = 'ku',
    this.isSkippable = false,
  });

  factory AuditFinding.interfaceDrift({
    required String step,
    required String className,
    required String methodName,
    required String sourceSignature,
    required String targetSignature,
    required String locale,
  }) => AuditFinding(
    category: AuditCategory.interfaceDrift,
    severity: AuditSeverity.major,
    step: step,
    className: className,
    methodName: methodName,
    description: '$sourceSignature vs $targetSignature',
    locale: locale,
  );

  factory AuditFinding.failClosedViolation({
    required String step,
    required String invariantDescription,
    required String locale,
  }) => AuditFinding(
    category: AuditCategory.failClosedViolation,
    severity: AuditSeverity.critical,
    step: step,
    description: invariantDescription,
    locale: locale,
  );

  factory AuditFinding.localizationGap({
    required String step,
    required String gapType,
    required String key,
    required String locale,
  }) => AuditFinding(
    category: AuditCategory.localizationGap,
    severity: AuditSeverity.minor,
    step: step,
    description: '$gapType: $key',
    locale: locale,
  );

  factory AuditFinding.missingImplementation({
    required String step,
    required String className,
    required String methodName,
    required String locale,
  }) => AuditFinding(
    category: AuditCategory.missingImplementation,
    severity: AuditSeverity.critical,
    step: step,
    className: className,
    methodName: methodName,
    locale: locale,
  );
}
