/// Step 24 — Trigger Normalization Service Tests
///
/// Structural tests for TriggerNormalizationService.
/// Normalization adds metadata keys: isScreenAction, normalizedFrom.
/// No Flutter/Dart SDK — structural validation only, NEVER claim runtime test results.

import 'package:aura_assistant/features/trigger_integration/domain/entities/trigger_request.dart';
import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_type.dart';
import 'package:aura_assistant/features/trigger_integration/application/normalization/trigger_normalization_service.dart';

void main() {
  group('TriggerNormalizationService', () {
    test('normalize returns new request with normalizedFrom metadata', () {
      final service = TriggerNormalizationService();
      final original = TriggerRequest(
        requestId: 'norm-001',
        triggerType: TriggerType.quickSettings,
        source: 'qs',
        timestamp: DateTime.now(),
      );
      final normalized = service.normalize(original);
      expect(normalized.requestId, equals('norm-001'));
      expect(normalized.metadata['normalizedFrom'], isNotNull);
    });

    test('normalize adds isScreenAction metadata for non-voice input', () {
      final service = TriggerNormalizationService();
      final original = TriggerRequest(
        requestId: 'norm-002',
        triggerType: TriggerType.inApp,
        source: 'app',
        timestamp: DateTime.now(),
        isVoiceInput: false,
      );
      final normalized = service.normalize(original);
      expect(normalized.metadata['isScreenAction'], isNotNull);
    });

    test('normalize preserves original locale (ku)', () {
      final service = TriggerNormalizationService();
      final original = TriggerRequest(
        requestId: 'norm-003',
        triggerType: TriggerType.inApp,
        source: 'app',
        timestamp: DateTime.now(),
        locale: 'ku',
      );
      final normalized = service.normalize(original);
      expect(normalized.locale, equals('ku'));
    });

    test('normalize preserves textPayload', () {
      final service = TriggerNormalizationService();
      final original = TriggerRequest(
        requestId: 'norm-004',
        triggerType: TriggerType.notificationAction,
        source: 'notification',
        timestamp: DateTime.now(),
        textPayload: 'reply_action',
      );
      final normalized = service.normalize(original);
      expect(normalized.textPayload, equals('reply_action'));
    });

    test('normalize preserves triggerType', () {
      final service = TriggerNormalizationService();
      final original = TriggerRequest(
        requestId: 'norm-005',
        triggerType: TriggerType.assistantLongPress,
        source: 'assistant',
        timestamp: DateTime.now(),
      );
      final normalized = service.normalize(original);
      expect(normalized.triggerType, equals(TriggerType.assistantLongPress));
    });

    test('normalize returns new instance (not same reference)', () {
      final service = TriggerNormalizationService();
      final original = TriggerRequest(
        requestId: 'norm-006',
        triggerType: TriggerType.inApp,
        source: 'app',
        timestamp: DateTime.now(),
      );
      final normalized = service.normalize(original);
      expect(identical(normalized, original), isFalse);
    });
  });
}
