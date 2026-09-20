/// Step 24 — Trigger Result Value Object Tests
///
/// Structural tests for TriggerResultVO and TriggerResultCategory.
/// FAIL-CLOSED: unknown/error → denied or failed category.
/// No Flutter/Dart SDK — structural validation only, NEVER claim runtime test results.

import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_result_vo.dart';

void main() {
  group('TriggerResultCategory', () {
    test('has all expected categories', () {
      expect(TriggerResultCategory.values, containsAll([
        TriggerResultCategory.launched,
        TriggerResultCategory.denied,
        TriggerResultCategory.failed,
        TriggerResultCategory.unavailable,
      ]));
    });

    test('fromName parses known categories', () {
      expect(TriggerResultCategory.fromName('launched'),
          equals(TriggerResultCategory.launched));
      expect(TriggerResultCategory.fromName('denied'),
          equals(TriggerResultCategory.denied));
      expect(TriggerResultCategory.fromName('failed'),
          equals(TriggerResultCategory.failed));
      expect(TriggerResultCategory.fromName('unavailable'),
          equals(TriggerResultCategory.unavailable));
    });

    test('FAIL-CLOSED: fromName with unknown string returns denied', () {
      expect(TriggerResultCategory.fromName('nonexistent'),
          equals(TriggerResultCategory.denied));
      expect(TriggerResultCategory.fromName(''),
          equals(TriggerResultCategory.denied));
    });
  });

  group('TriggerResultVO', () {
    test('launched VO has correct properties', () {
      final vo = TriggerResultVO.launched('orch-123');
      expect(vo.category, equals(TriggerResultCategory.launched));
      expect(vo.isLaunched, isTrue);
      expect(vo.isDenied, isFalse);
      expect(vo.isFailed, isFalse);
      expect(vo.isUnavailable, isFalse);
      expect(vo.orchestrationId, equals('orch-123'));
    });

    test('denied VO has correct properties', () {
      final vo = TriggerResultVO.denied('security_policy');
      expect(vo.category, equals(TriggerResultCategory.denied));
      expect(vo.isDenied, isTrue);
      expect(vo.isLaunched, isFalse);
      expect(vo.denialReason, equals('security_policy'));
    });

    test('failed VO has correct properties', () {
      final vo = TriggerResultVO.failed('engine_crash');
      expect(vo.category, equals(TriggerResultCategory.failed));
      expect(vo.isFailed, isTrue);
      expect(vo.isLaunched, isFalse);
      expect(vo.errorMessage, equals('engine_crash'));
    });

    test('unavailable VO has correct properties', () {
      final vo = TriggerResultVO.unavailable('engine_offline');
      expect(vo.category, equals(TriggerResultCategory.unavailable));
      expect(vo.isUnavailable, isTrue);
      expect(vo.isLaunched, isFalse);
      expect(vo.errorMessage, equals('engine_offline'));
    });

    test('toString contains category name', () {
      final vo = TriggerResultVO.denied('test');
      expect(vo.toString(), contains('denied'));
    });
  });
}
