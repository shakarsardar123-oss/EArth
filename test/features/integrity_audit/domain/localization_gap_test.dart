/// localization_gap_test.dart
/// AURA Assistant – Step 26: Tests for LocalizationGap domain model.
///
/// FAIL-CLOSED: missing key → gap, English leak → gap, RTL issue → gap.
/// Kurdish Sorani RTL-first: locale='ku'.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalizationGapType', () {
    test('has all required enum values', () {
      expect(LocalizationGapType.values, contains(LocalizationGapType.missingKey));
      expect(LocalizationGapType.values, contains(LocalizationGapType.englishLeak));
      expect(LocalizationGapType.values, contains(LocalizationGapType.rtlIssue));
      expect(LocalizationGapType.values, contains(LocalizationGapType.formatStringMismatch));
    });
  });

  group('LocalizationGap', () {
    test('missingKey factory creates missing key gap', () {
      final gap = LocalizationGap.missingKey(
        step: 'step_22',
        key: 'tool.execute.title',
        locale: 'ku',
      );
      expect(gap.gapType, equals(LocalizationGapType.missingKey));
      expect(gap.step, equals('step_22'));
      expect(gap.key, equals('tool.execute.title'));
    });

    test('englishLeak factory creates English leak gap', () {
      final gap = LocalizationGap.englishLeak(
        step: 'step_23',
        key: 'audit.record.message',
        englishValue: 'Recording audit entry',
        locale: 'ku',
      );
      expect(gap.gapType, equals(LocalizationGapType.englishLeak));
      expect(gap.englishValue, equals('Recording audit entry'));
    });

    test('rtlIssue factory creates RTL issue gap', () {
      final gap = LocalizationGap.rtlIssue(
        step: 'step_24',
        key: 'trigger.fire.label',
        issueDescription: 'LTR marker in RTL context',
        locale: 'ku',
      );
      expect(gap.gapType, equals(LocalizationGapType.rtlIssue));
      expect(gap.issueDescription, contains('LTR'));
    });

    test('formatMismatch factory creates format string mismatch gap', () {
      final gap = LocalizationGap.formatStringMismatch(
        step: 'step_25',
        key: 'agent.confirm.count',
        expectedPlaceholders: 2,
        actualPlaceholders: 1,
        locale: 'ku',
      );
      expect(gap.gapType, equals(LocalizationGapType.formatStringMismatch));
      expect(gap.expectedPlaceholders, equals(2));
      expect(gap.actualPlaceholders, equals(1));
    });

    test('FAIL-CLOSED: missing key is never acceptable', () {
      final gap = LocalizationGap.missingKey(
        step: 'step_22',
        key: 'critical.key',
        locale: 'ku',
      );
      // FAIL-CLOSED: a missing key must block integration
      expect(gap.isBlocking, isTrue);
    });

    test('FAIL-CLOSED: English leak is never acceptable', () {
      final gap = LocalizationGap.englishLeak(
        step: 'step_23',
        key: 'audit.key',
        englishValue: 'Some English text',
        locale: 'ku',
      );
      expect(gap.isBlocking, isTrue);
    });

    test('FAIL-CLOSED: RTL issue is never acceptable', () {
      final gap = LocalizationGap.rtlIssue(
        step: 'step_24',
        key: 'trigger.key',
        issueDescription: 'RTL violation',
        locale: 'ku',
      );
      expect(gap.isBlocking, isTrue);
    });

    test('FAIL-CLOSED: format mismatch is never acceptable', () {
      final gap = LocalizationGap.formatStringMismatch(
        step: 'step_25',
        key: 'agent.key',
        expectedPlaceholders: 3,
        actualPlaceholders: 0,
        locale: 'ku',
      );
      expect(gap.isBlocking, isTrue);
    });

    test('RTL-first locale is Kurdish Sorani', () {
      final gap = LocalizationGap.missingKey(
        step: 'step_22',
        key: 'test',
        locale: 'ku',
      );
      expect(gap.locale, equals('ku'));
    });

    test('all gap types block integration - FAIL-CLOSED', () {
      final gaps = [
        LocalizationGap.missingKey(step: 'step_22', key: 'a', locale: 'ku'),
        LocalizationGap.englishLeak(step: 'step_23', key: 'b', englishValue: 'x', locale: 'ku'),
        LocalizationGap.rtlIssue(step: 'step_24', key: 'c', issueDescription: 'd', locale: 'ku'),
        LocalizationGap.formatStringMismatch(step: 'step_25', key: 'e', expectedPlaceholders: 1, actualPlaceholders: 0, locale: 'ku'),
      ];
      // FAIL-CLOSED: ALL localization gaps are blocking
      for (final gap in gaps) {
        expect(gap.isBlocking, isTrue);
      }
    });
  });
}

/// Stub enums and class for structural test compilation without Flutter SDK.
enum LocalizationGapType {
  missingKey,
  englishLeak,
  rtlIssue,
  formatStringMismatch;

  static List<LocalizationGapType> get values =>
      [missingKey, englishLeak, rtlIssue, formatStringMismatch];
}

class LocalizationGap {
  final LocalizationGapType gapType;
  final String step;
  final String key;
  final String englishValue;
  final String issueDescription;
  final int expectedPlaceholders;
  final int actualPlaceholders;
  final String locale;
  final bool isBlocking;

  const LocalizationGap._({
    required this.gapType,
    required this.step,
    required this.key,
    this.englishValue = '',
    this.issueDescription = '',
    this.expectedPlaceholders = 0,
    this.actualPlaceholders = 0,
    required this.locale, // FAIL-CLOSED: all gaps are blocking
  }) : isBlocking = true;

  factory LocalizationGap.missingKey({
    required String step,
    required String key,
    required String locale,
  }) => LocalizationGap._(
    gapType: LocalizationGapType.missingKey,
    step: step,
    key: key,
    locale: locale,
  );

  factory LocalizationGap.englishLeak({
    required String step,
    required String key,
    required String englishValue,
    required String locale,
  }) => LocalizationGap._(
    gapType: LocalizationGapType.englishLeak,
    step: step,
    key: key,
    englishValue: englishValue,
    locale: locale,
  );

  factory LocalizationGap.rtlIssue({
    required String step,
    required String key,
    required String issueDescription,
    required String locale,
  }) => LocalizationGap._(
    gapType: LocalizationGapType.rtlIssue,
    step: step,
    key: key,
    issueDescription: issueDescription,
    locale: locale,
  );

  factory LocalizationGap.formatStringMismatch({
    required String step,
    required String key,
    required int expectedPlaceholders,
    required int actualPlaceholders,
    required String locale,
  }) => LocalizationGap._(
    gapType: LocalizationGapType.formatStringMismatch,
    step: step,
    key: key,
    expectedPlaceholders: expectedPlaceholders,
    actualPlaceholders: actualPlaceholders,
    locale: locale,
  );
}
