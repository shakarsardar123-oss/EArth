/// Step 24 — Trigger Request Tests
///
/// Structural tests for TriggerRequest entity.
/// FAIL-CLOSED: unknown() factory creates unauthorizable request.
/// No Flutter/Dart SDK — structural validation only, NEVER claim runtime test results.

import 'dart:core';

import 'package:aura_assistant/features/trigger_integration/domain/entities/trigger_request.dart';
import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_type.dart';

void main() {
  group('TriggerRequest', () {
    test('constructs with required fields and defaults', () {
      final now = DateTime.now();
      final req = TriggerRequest(
        requestId: 'req-001',
        triggerType: TriggerType.quickSettings,
        source: 'quick_settings',
        timestamp: now,
      );
      expect(req.requestId, equals('req-001'));
      expect(req.triggerType, equals(TriggerType.quickSettings));
      expect(req.source, equals('quick_settings'));
      expect(req.timestamp, equals(now));
      // Defaults
      expect(req.textPayload, isNull);
      expect(req.isVoiceInput, isFalse);
      expect(req.metadata, isA<Map<String, dynamic>>());
      expect(req.metadata, isEmpty);
      expect(req.locale, equals('ku'));
    });

    test('constructs with all optional fields', () {
      final now = DateTime.now();
      final req = TriggerRequest(
        requestId: 'req-002',
        triggerType: TriggerType.notificationAction,
        source: 'notification',
        timestamp: now,
        textPayload: 'reply_action',
        isVoiceInput: true,
        metadata: {'actionLabel': 'reply'},
        locale: 'en',
      );
      expect(req.textPayload, equals('reply_action'));
      expect(req.isVoiceInput, isTrue);
      expect(req.metadata['actionLabel'], equals('reply'));
      expect(req.locale, equals('en'));
    });

    test('isAuthorizable returns true for authorizable types', () {
      final req = TriggerRequest(
        requestId: 'req-003',
        triggerType: TriggerType.quickSettings,
        source: 'qs',
        timestamp: DateTime.now(),
      );
      expect(req.isAuthorizable, isTrue);
    });

    test('FAIL-CLOSED: isAuthorizable returns false for unknown type', () {
      final req = TriggerRequest(
        requestId: 'req-004',
        triggerType: TriggerType.unknown,
        source: 'unknown',
        timestamp: DateTime.now(),
      );
      expect(req.isAuthorizable, isFalse);
    });

    test('hasTextPayload returns true when payload present', () {
      final req = TriggerRequest(
        requestId: 'req-005',
        triggerType: TriggerType.inApp,
        source: 'app',
        timestamp: DateTime.now(),
        textPayload: 'hello',
      );
      expect(req.hasTextPayload, isTrue);
    });

    test('hasTextPayload returns false when payload null', () {
      final req = TriggerRequest(
        requestId: 'req-006',
        triggerType: TriggerType.inApp,
        source: 'app',
        timestamp: DateTime.now(),
      );
      expect(req.hasTextPayload, isFalse);
    });

    test('unknown factory creates unauthorizable request', () {
      final req = TriggerRequest.unknown();
      expect(req.triggerType, equals(TriggerType.unknown));
      expect(req.isAuthorizable, isFalse);
      expect(req.source, equals('unknown'));
      expect(req.locale, equals('ku'));
    });

    test('default locale is Kurdish Sorani (ku)', () {
      final req = TriggerRequest(
        requestId: 'req-007',
        triggerType: TriggerType.inApp,
        source: 'app',
        timestamp: DateTime.now(),
      );
      expect(req.locale, equals('ku'));
    });

    test('metadata is empty map by default', () {
      final req = TriggerRequest(
        requestId: 'req-008',
        triggerType: TriggerType.inApp,
        source: 'app',
        timestamp: DateTime.now(),
      );
      expect(req.metadata, isNotNull);
      expect(req.metadata, isEmpty);
    });

    test('toString contains requestId and type', () {
      final req = TriggerRequest(
        requestId: 'req-009',
        triggerType: TriggerType.quickSettings,
        source: 'qs',
        timestamp: DateTime.now(),
      );
      final str = req.toString();
      expect(str, contains('req-009'));
      expect(str, contains('quickSettings'));
    });
  });
}
