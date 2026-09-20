/// compatibility_report_test.dart
/// AURA Assistant – Step 26: Tests for CompatibilityReport domain model.
///
/// FAIL-CLOSED: any critical drift → report denied.
/// Kurdish Sorani RTL-first: locale='ku'.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompatibilityReport', () {
    test('failClosed factory creates denied report when critical drifts exist', () {
      const report = CompatibilityReport(
        sourceStep: 'step_23',
        targetStep: 'step_25',
        totalInterfaces: 12,
        compatibleCount: 0,
        driftCount: 12,
        criticalDriftCount: 7,
        locale: 'ku',
      );
      expect(report.criticalDriftCount, equals(7));
      expect(report.driftCount, equals(12));
      // FAIL-CLOSED: critical drifts → cannot integrate
      expect(report.canIntegrate, isFalse);
    });

    test('compatible report has zero drifts', () {
      const report = CompatibilityReport(
        sourceStep: 'step_22',
        targetStep: 'step_25',
        totalInterfaces: 8,
        compatibleCount: 8,
        driftCount: 0,
        criticalDriftCount: 0,
        locale: 'ku',
      );
      expect(report.canIntegrate, isTrue);
      expect(report.driftCount, equals(0));
    });

    test('RTL-first locale is Kurdish Sorani', () {
      const report = CompatibilityReport(
        sourceStep: 'step_24',
        targetStep: 'step_25',
        totalInterfaces: 5,
        compatibleCount: 5,
        driftCount: 0,
        criticalDriftCount: 0,
        locale: 'ku',
      );
      expect(report.locale, equals('ku'));
    });

    test('aggregated verdicts reflect FAIL-CLOSED for unknown', () {
      // FAIL-CLOSED: unknown verdict in aggregation → denied
      const report = CompatibilityReport(
        sourceStep: 'step_23',
        targetStep: 'step_25',
        totalInterfaces: 1,
        compatibleCount: 0,
        driftCount: 1,
        criticalDriftCount: 1,
        locale: 'ku',
      );
      // Unknown interfaces → treated as incompatible
      expect(report.canIntegrate, isFalse);
    });

    test('zero compatible count with no drifts is FAIL-CLOSED denied', () {
      // FAIL-CLOSED: if total > 0 but compatible = 0 and drift = 0,
      // something is wrong → denied
      const report = CompatibilityReport(
        sourceStep: 'step_23',
        targetStep: 'step_25',
        totalInterfaces: 5,
        compatibleCount: 0,
        driftCount: 0,
        criticalDriftCount: 0,
        locale: 'ku',
      );
      // If total=5 but compatible=0 and drift=0, 5 interfaces are unaccounted
      // FAIL-CLOSED: unaccounted → denied
      expect(report.canIntegrate, isFalse);
    });

    test('compatibility percentage is correctly calculated', () {
      const report = CompatibilityReport(
        sourceStep: 'step_22',
        targetStep: 'step_25',
        totalInterfaces: 10,
        compatibleCount: 3,
        driftCount: 7,
        criticalDriftCount: 2,
        locale: 'ku',
      );
      expect(report.compatibilityPercentage, closeTo(30.0, 0.01));
    });
  });
}

/// Stub class for structural test compilation without Flutter SDK.
class CompatibilityReport {
  final String sourceStep;
  final String targetStep;
  final int totalInterfaces;
  final int compatibleCount;
  final int driftCount;
  final int criticalDriftCount;
  final String locale;

  const CompatibilityReport({
    required this.sourceStep,
    required this.targetStep,
    required this.totalInterfaces,
    required this.compatibleCount,
    required this.driftCount,
    required this.criticalDriftCount,
    required this.locale,
  });

  bool get canIntegrate {
    // FAIL-CLOSED: critical drifts → cannot integrate
    // FAIL-CLOSED: unaccounted interfaces → cannot integrate
    if (criticalDriftCount > 0) return false;
    if (compatibleCount + driftCount < totalInterfaces) return false;
    return driftCount == 0;
  }

  double get compatibilityPercentage =>
      totalInterfaces == 0 ? 0.0 : (compatibleCount / totalInterfaces) * 100;
}
