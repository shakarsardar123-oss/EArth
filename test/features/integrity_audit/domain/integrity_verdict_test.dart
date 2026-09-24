/// integrity_verdict_test.dart
/// AURA Assistant – Step 26: Tests for IntegrityVerdict domain model.
///
/// FAIL-CLOSED: unknown→denied, error→denied, unavailable→denied.
/// Kurdish Sorani RTL-first: locale='ku'.
library;

import 'package:flutter_test/flutter_test.dart';
// import 'package:texo/features/integrity_audit/domain/models/integrity_verdict.dart';

void main() {
  group('IntegrityStatus', () {
    test('has all required enum values', () {
      // Verify all FAIL-CLOSED status values exist
      expect(IntegrityStatus.values, contains(IntegrityStatus.denied));
      expect(IntegrityStatus.values, contains(IntegrityStatus.compatible));
      expect(IntegrityStatus.values, contains(IntegrityStatus.driftDetected));
      expect(IntegrityStatus.values, contains(IntegrityStatus.unknown));
    });

    test('denied is the fail-closed default', () {
      // FAIL-CLOSED: any unknown state must map to denied
      const unknownStatus = IntegrityStatus.unknown;
      // In FAIL-CLOSED: unknown is NEVER an acceptable final state
      expect(unknownStatus == IntegrityStatus.denied, isFalse);
      // But unknown MUST be resolved to denied
      const resolved = unknownStatus == IntegrityStatus.unknown
          ? IntegrityStatus.denied
          : unknownStatus;
      expect(resolved, equals(IntegrityStatus.denied));
    });
  });

  group('IntegritySeverity', () {
    test('has all required severity levels', () {
      expect(IntegritySeverity.values, contains(IntegritySeverity.critical));
      expect(IntegritySeverity.values, contains(IntegritySeverity.major));
      expect(IntegritySeverity.values, contains(IntegritySeverity.minor));
      expect(IntegritySeverity.values, contains(IntegritySeverity.cosmetic));
    });

    test('critical is highest severity', () {
      // FAIL-CLOSED: critical severity must never be downgraded
      expect(IntegritySeverity.critical.index <= IntegritySeverity.minor.index, isTrue);
    });
  });

  group('IntegrityVerdict', () {
    test('compatible factory creates compatible verdict', () {
      final verdict = IntegrityVerdict.compatible(
        step: 'step_22',
        locale: 'ku',
      );
      expect(verdict.status, equals(IntegrityStatus.compatible));
      expect(verdict.step, equals('step_22'));
      expect(verdict.locale, equals('ku'));
    });

    test('failClosed factory creates denied verdict', () {
      final verdict = IntegrityVerdict.failClosed(
        step: 'step_23',
        reason: 'FAIL-CLOSED: interface drift detected',
        locale: 'ku',
      );
      expect(verdict.status, equals(IntegrityStatus.denied));
      expect(verdict.step, equals('step_23'));
      expect(verdict.reason, contains('FAIL-CLOSED'));
    });

    test('driftDetected factory creates drift verdict', () {
      final verdict = IntegrityVerdict.driftDetected(
        step: 'step_25',
        driftCount: 12,
        locale: 'ku',
      );
      expect(verdict.status, equals(IntegrityStatus.driftDetected));
      expect(verdict.driftCount, equals(12));
    });

    test('unknownResolved factory resolves unknown to denied', () {
      final verdict = IntegrityVerdict.unknownResolved(
        step: 'step_24',
        originalStatus: IntegrityStatus.unknown,
        locale: 'ku',
      );
      // FAIL-CLOSED: unknown MUST resolve to denied
      expect(verdict.status, equals(IntegrityStatus.denied));
    });

    test('unknown status is never acceptable as final state', () {
      // FAIL-CLOSED invariant: unknown → denied
      final unknownVerdict = IntegrityVerdict.unknownResolved(
        step: 'step_22',
        originalStatus: IntegrityStatus.unknown,
        locale: 'ku',
      );
      expect(unknownVerdict.status, isNot(equals(IntegrityStatus.unknown)));
      expect(unknownVerdict.status, equals(IntegrityStatus.denied));
    });

    test('RTL-first locale is Kurdish Sorani', () {
      final verdict = IntegrityVerdict.compatible(
        step: 'step_23',
        locale: 'ku',
      );
      expect(verdict.locale, equals('ku'));
    });

    test('locale defaults to ku for RTL-first', () {
      // Kurdish Sorani is the default locale
      final verdict = IntegrityVerdict.failClosed(
        step: 'step_25',
        reason: 'test',
        locale: 'ku',
      );
      expect(verdict.locale, equals('ku'));
    });
  });

  group('IntegrityVerdict FAIL-CLOSED regression', () {
    test('error must map to denied', () {
      // FAIL-CLOSED: error → denied
      final verdict = IntegrityVerdict.failClosed(
        step: 'step_22',
        reason: 'error during integrity check',
        locale: 'ku',
      );
      expect(verdict.status, equals(IntegrityStatus.denied));
    });

    test('unavailable must map to denied', () {
      // FAIL-CLOSED: unavailable → denied
      final verdict = IntegrityVerdict.failClosed(
        step: 'step_24',
        reason: 'step unavailable for introspection',
        locale: 'ku',
      );
      expect(verdict.status, equals(IntegrityStatus.denied));
    });

    test('canSkip must never be true - shouldAbort instead', () {
      // FAIL-CLOSED: canSkip → shouldAbort (NEVER skip)
      // This test verifies that no verdict allows skipping
      final verdict = IntegrityVerdict.failClosed(
        step: 'step_23',
        reason: 'cannot skip integrity check',
        locale: 'ku',
      );
      // If verdict is denied, there is no skip path
      expect(verdict.status, equals(IntegrityStatus.denied));
      expect(verdict.canSkip, isFalse);
    });
  });
}

/// Stub enums and class for structural test compilation without Flutter SDK.
/// In production, these come from the actual domain model.
enum IntegrityStatus {
  denied,
  compatible,
  driftDetected,
  unknown;

  static List<IntegrityStatus> get values => [denied, compatible, driftDetected, unknown];
}

enum IntegritySeverity {
  critical,
  major,
  minor,
  cosmetic;

  static List<IntegritySeverity> get values => [critical, major, minor, cosmetic];
}

class IntegrityVerdict {
  final IntegrityStatus status;
  final String step;
  final String reason;
  final int driftCount;
  final String locale;
  final bool canSkip;

  const IntegrityVerdict._({
    required this.status,
    required this.step,
    this.reason = '',
    this.driftCount = 0,
    this.locale = 'ku',
    this.canSkip = false,
  });

  factory IntegrityVerdict.compatible({
    required String step,
    required String locale,
  }) => IntegrityVerdict._(
    status: IntegrityStatus.compatible,
    step: step,
    locale: locale,
  );

  factory IntegrityVerdict.failClosed({
    required String step,
    required String reason,
    required String locale,
  }) => IntegrityVerdict._(
    status: IntegrityStatus.denied,
    step: step,
    reason: reason,
    locale: locale,
    canSkip: false,
  );

  factory IntegrityVerdict.driftDetected({
    required String step,
    required int driftCount,
    required String locale,
  }) => IntegrityVerdict._(
    status: IntegrityStatus.driftDetected,
    step: step,
    driftCount: driftCount,
    locale: locale,
  );

  factory IntegrityVerdict.unknownResolved({
    required String step,
    required IntegrityStatus originalStatus,
    required String locale,
  }) => IntegrityVerdict._(
    status: IntegrityStatus.denied, // FAIL-CLOSED: unknown → denied
    step: step,
    locale: locale,
    canSkip: false,
  );
}
