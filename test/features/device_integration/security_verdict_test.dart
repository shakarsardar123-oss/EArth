/// Tests for SecurityVerdict, SecurityVerdictType, and
/// ProhibitedActionsRegistry.
/// Covers: allowed/denied factories, isAllowed/isDenied getters,
/// equality, ProhibitedActionsRegistry.check, isProhibitedActionName.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/device_integration/domain/models/security_verdict.dart';
import 'package:aura_assistant/features/device_integration/domain/entities/device_action.dart';

void main() {
  // ─── SecurityVerdict factories ───────────────────────────────────
  group('SecurityVerdict factories', () {
    test('allowed factory creates allowed verdict', () {
      final v = SecurityVerdict.allowed();
      expect(v.type, SecurityVerdictType.allowed);
      expect(v.isAllowed, isTrue);
      expect(v.isDenied, isFalse);
    });

    test('allowed factory with reason', () {
      final v = SecurityVerdict.allowed('safe action');
      expect(v.reason, 'safe action');
      expect(v.isAllowed, isTrue);
    });

    test('denied factory creates denied verdict', () {
      final v = SecurityVerdict.denied('prohibited');
      expect(v.type, SecurityVerdictType.denied);
      expect(v.isDenied, isTrue);
      expect(v.isAllowed, isFalse);
      expect(v.reason, 'prohibited');
    });

    test('denied factory with rule', () {
      final v = SecurityVerdict.denied('prohibited', rule: 'no_aimbot');
      expect(v.rule, 'no_aimbot');
    });

    test('allowed factory has null rule by default', () {
      final v = SecurityVerdict.allowed();
      expect(v.rule, isNull);
    });
  });

  // ─── SecurityVerdict equality ────────────────────────────────────
  group('SecurityVerdict equality', () {
    test('same type, reason, and rule are equal', () {
      final a = SecurityVerdict.denied('bad', rule: 'r1');
      final b = SecurityVerdict.denied('bad', rule: 'r1');
      expect(a, equals(b));
    });

    test('different type is not equal', () {
      final a = SecurityVerdict.allowed('ok');
      final b = SecurityVerdict.denied('ok');
      expect(a, isNot(equals(b)));
    });

    test('different reason is not equal', () {
      final a = SecurityVerdict.denied('a');
      final b = SecurityVerdict.denied('b');
      expect(a, isNot(equals(b)));
    });

    test('different rule is not equal', () {
      final a = SecurityVerdict.denied('x', rule: 'r1');
      final b = SecurityVerdict.denied('x', rule: 'r2');
      expect(a, isNot(equals(b)));
    });
  });

  // ─── ProhibitedActionsRegistry ───────────────────────────────────
  group('ProhibitedActionsRegistry', () {
    test('prohibitedActionTypes contains expected entries', () {
      final types = ProhibitedActionsRegistry.prohibitedActionTypes;
      expect(types, contains('auto_aim'));
      expect(types, contains('aimbot'));
      // Verify it's non-empty
      expect(types, isNotEmpty);
    });

    test('prohibitedTargetKeywords contains expected entries', () {
      final keywords = ProhibitedActionsRegistry.prohibitedTargetKeywords;
      expect(keywords, contains('aimbot'));
      expect(keywords, contains('cheat'));
      expect(keywords, contains('hack'));
      expect(keywords, isNotEmpty);
    });

    test('check allows a safe tap action', () {
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
        targetLabel: 'settings button',
      );
      final verdict = ProhibitedActionsRegistry.check(action);
      expect(verdict.isAllowed, isTrue);
    });

    test('check denies action with prohibited target label', () {
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
        targetLabel: 'aimbot',
      );
      final verdict = ProhibitedActionsRegistry.check(action);
      expect(verdict.isDenied, isTrue);
    });

    test('isProhibitedActionName returns true for prohibited names', () {
      expect(ProhibitedActionsRegistry.isProhibitedActionName('auto_aim'),
          isTrue);
      expect(ProhibitedActionsRegistry.isProhibitedActionName('aimbot'),
          isTrue);
    });

    test('isProhibitedActionName returns false for safe names', () {
      expect(ProhibitedActionsRegistry.isProhibitedActionName('tap'),
          isFalse);
      expect(ProhibitedActionsRegistry.isProhibitedActionName('openApp'),
          isFalse);
    });
  });
}
