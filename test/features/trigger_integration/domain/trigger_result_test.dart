/// Step 24 — Trigger Result Tests
///
/// Structural tests for TriggerResult entity.
/// FAIL-CLOSED: all terminal states cover deny/failed/unavailable.
/// No Flutter/Dart SDK — structural validation only, NEVER claim runtime test results.

import 'package:aura_assistant/features/trigger_integration/domain/entities/trigger_result.dart';
import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_type.dart';
import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_state.dart';

void main() {
  group('TriggerResult', () {
    test('launched factory creates successful result', () {
      final result = TriggerResult.launched(
        requestId: 'req-001',
        triggerType: TriggerType.quickSettings,
        orchestrationId: 'orch-001',
      );
      expect(result.launched, isTrue);
      expect(result.wasDenied, isFalse);
      expect(result.wasFailed, isFalse);
      expect(result.wasUnavailable, isFalse);
      expect(result.finalPhase, equals(TriggerPhase.launched));
      expect(result.requestId, equals('req-001'));
      expect(result.triggerType, equals(TriggerType.quickSettings));
    });

    test('denied factory creates denied result', () {
      final result = TriggerResult.denied(
        requestId: 'req-002',
        triggerType: TriggerType.assistantLongPress,
        denialReason: 'security_policy',
        localizedResponse: 'ڕێگەپێنەدراو',
      );
      expect(result.wasDenied, isTrue);
      expect(result.launched, isFalse);
      expect(result.finalPhase, equals(TriggerPhase.denied));
      expect(result.denialReason, equals('security_policy'));
      expect(result.localizedResponse, equals('ڕێگەپێنەدراو'));
    });

    test('failed factory creates failed result', () {
      final result = TriggerResult.failed(
        requestId: 'req-003',
        triggerType: TriggerType.inApp,
        errorMessage: 'engine_crash',
      );
      expect(result.wasFailed, isTrue);
      expect(result.launched, isFalse);
      expect(result.finalPhase, equals(TriggerPhase.failed));
      expect(result.errorMessage, equals('engine_crash'));
    });

    test('unavailable factory creates unavailable result', () {
      final result = TriggerResult.unavailable(
        requestId: 'req-004',
        triggerType: TriggerType.homeLongPress,
        errorMessage: 'engine_not_running',
      );
      expect(result.wasUnavailable, isTrue);
      expect(result.launched, isFalse);
      expect(result.finalPhase, equals(TriggerPhase.unavailable));
    });

    test('all factories set requestId and triggerType', () {
      for (final factoryResult in [
        TriggerResult.launched(requestId: 'r1', triggerType: TriggerType.inApp, orchestrationId: 'o1'),
        TriggerResult.denied(requestId: 'r2', triggerType: TriggerType.inApp, denialReason: 'x', localizedResponse: 'y'),
        TriggerResult.failed(requestId: 'r3', triggerType: TriggerType.inApp, errorMessage: 'x'),
        TriggerResult.unavailable(requestId: 'r4', triggerType: TriggerType.inApp, errorMessage: 'x'),
      ]) {
        expect(factoryResult.requestId, isNotNull);
        expect(factoryResult.triggerType, equals(TriggerType.inApp));
      }
    });

    test('terminal states are mutually exclusive', () {
      final launched = TriggerResult.launched(
        requestId: 'r', triggerType: TriggerType.inApp, orchestrationId: 'o');
      final denied = TriggerResult.denied(
        requestId: 'r', triggerType: TriggerType.inApp,
        denialReason: 'x', localizedResponse: 'y');
      final failed = TriggerResult.failed(
        requestId: 'r', triggerType: TriggerType.inApp, errorMessage: 'x');
      final unavailable = TriggerResult.unavailable(
        requestId: 'r', triggerType: TriggerType.inApp, errorMessage: 'x');

      // Launched: only launched is true
      expect(launched.launched, isTrue);
      expect(launched.wasDenied || launched.wasFailed || launched.wasUnavailable, isFalse);

      // Denied: only wasDenied is true
      expect(denied.wasDenied, isTrue);
      expect(denied.launched || denied.wasFailed || denied.wasUnavailable, isFalse);

      // Failed: only wasFailed is true
      expect(failed.wasFailed, isTrue);
      expect(failed.launched || failed.wasDenied || failed.wasUnavailable, isFalse);

      // Unavailable: only wasUnavailable is true
      expect(unavailable.wasUnavailable, isTrue);
      expect(unavailable.launched || unavailable.wasDenied || unavailable.wasFailed, isFalse);
    });

    test('toString contains meaningful info', () {
      final result = TriggerResult.denied(
        requestId: 'req-099',
        triggerType: TriggerType.quickSettings,
        denialReason: 'policy',
        localizedResponse: 'test',
      );
      final str = result.toString();
      expect(str, contains('req-099'));
      expect(str, contains('denied'));
    });
  });
}
