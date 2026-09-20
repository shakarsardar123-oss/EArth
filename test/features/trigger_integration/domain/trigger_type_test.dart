/// Step 24 — Trigger Type Tests
///
/// Structural tests for TriggerType enum.
/// FAIL-CLOSED: unknown types are NEVER authorizable.
/// No Flutter/Dart SDK — structural validation only, NEVER claim runtime test results.

import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_type.dart';

void main() {
  group('TriggerType', () {
    test('has all expected values', () {
      expect(TriggerType.values, containsAll([
        TriggerType.quickSettings,
        TriggerType.assistantLongPress,
        TriggerType.homeLongPress,
        TriggerType.notificationAction,
        TriggerType.inApp,
        TriggerType.unknown,
      ]));
    });

    test('known types are authorizable', () {
      expect(TriggerType.quickSettings.isAuthorizable, isTrue);
      expect(TriggerType.assistantLongPress.isAuthorizable, isTrue);
      expect(TriggerType.homeLongPress.isAuthorizable, isTrue);
      expect(TriggerType.notificationAction.isAuthorizable, isTrue);
      expect(TriggerType.inApp.isAuthorizable, isTrue);
    });

    test('FAIL-CLOSED: unknown type is NOT authorizable', () {
      expect(TriggerType.unknown.isAuthorizable, isFalse);
    });

    test('fromName parses known types correctly', () {
      expect(TriggerType.fromName('quickSettings'),
          equals(TriggerType.quickSettings));
      expect(TriggerType.fromName('assistantLongPress'),
          equals(TriggerType.assistantLongPress));
      expect(TriggerType.fromName('homeLongPress'),
          equals(TriggerType.homeLongPress));
      expect(TriggerType.fromName('notificationAction'),
          equals(TriggerType.notificationAction));
      expect(TriggerType.fromName('inApp'), equals(TriggerType.inApp));
    });

    test('FAIL-CLOSED: fromName with unknown string returns unknown', () {
      expect(TriggerType.fromName('nonexistent'),
          equals(TriggerType.unknown));
      expect(TriggerType.fromName(''), equals(TriggerType.unknown));
      expect(TriggerType.fromName('RANDOM'),
          equals(TriggerType.unknown));
    });

    test('logLabel returns name string', () {
      expect(TriggerType.quickSettings.logLabel, equals('quickSettings'));
      expect(TriggerType.unknown.logLabel, equals('unknown'));
    });
  });
}
