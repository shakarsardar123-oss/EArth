/// Step 24 — Trigger UI State Tests
///
/// Structural tests for TriggerUiState.
/// FAIL-CLOSED: default state is idle/denied-oriented.
/// No Flutter/Dart SDK — structural validation only, NEVER claim runtime test results.

import 'package:aura_assistant/features/trigger_integration/presentation/state/trigger_ui_state.dart';
import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_type.dart';
import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_state.dart';
import 'package:aura_assistant/features/trigger_integration/domain/entities/trigger_result.dart';

void main() {
  group('TriggerUiState', () {
    test('initial factory creates idle state', () {
      final state = TriggerUiState.initial();
      expect(state.currentPhase, equals(TriggerPhase.idle));
      expect(state.isLoading, isFalse);
      expect(state.wasDenied, isFalse);
      expect(state.wasFailed, isFalse);
      expect(state.isUnavailable, isFalse);
      expect(state.isLaunched, isFalse);
      expect(state.lastResult, isNull);
      expect(state.activeTriggerType, isNull);
      expect(state.errorMessage, isNull);
      expect(state.localizedDenialReason, isNull);
    });

    test('validating factory creates loading state with type', () {
      final state = TriggerUiState.validating(TriggerType.quickSettings);
      expect(state.currentPhase, equals(TriggerPhase.validating));
      expect(state.isLoading, isTrue);
      expect(state.activeTriggerType, equals(TriggerType.quickSettings));
    });

    test('denied factory creates denied state with result', () {
      final result = TriggerResult.denied(
        requestId: 'ui-001',
        triggerType: TriggerType.quickSettings,
        denialReason: 'security_policy',
        localizedResponse: 'ڕێگەپێنەدراو',
      );
      final state = TriggerUiState.denied(result);
      expect(state.currentPhase, equals(TriggerPhase.denied));
      expect(state.wasDenied, isTrue);
      expect(state.lastResult, same(result));
      expect(state.localizedDenialReason, equals('ڕێگەپێنەدراو'));
    });

    test('failed factory creates failed state', () {
      final result = TriggerResult.failed(
        requestId: 'ui-002',
        triggerType: TriggerType.inApp,
        errorMessage: 'crash',
      );
      final state = TriggerUiState.failed(result);
      expect(state.currentPhase, equals(TriggerPhase.failed));
      expect(state.wasFailed, isTrue);
      expect(state.errorMessage, equals('crash'));
    });

    test('unavailable factory creates unavailable state', () {
      final result = TriggerResult.unavailable(
        requestId: 'ui-003',
        triggerType: TriggerType.homeLongPress,
        errorMessage: 'engine_off',
      );
      final state = TriggerUiState.unavailable(result);
      expect(state.currentPhase, equals(TriggerPhase.unavailable));
      expect(state.isUnavailable, isTrue);
      expect(state.errorMessage, equals('engine_off'));
    });

    test('launched factory creates launched state', () {
      final result = TriggerResult.launched(
        requestId: 'ui-004',
        triggerType: TriggerType.quickSettings,
        orchestrationId: 'orch-ui-004',
      );
      final state = TriggerUiState.launched(result);
      expect(state.currentPhase, equals(TriggerPhase.launched));
      expect(state.isLaunched, isTrue);
      expect(state.lastResult, same(result));
    });

    test('default constructor creates idle state', () {
      const state = TriggerUiState();
      expect(state.currentPhase, equals(TriggerPhase.idle));
      expect(state.isLoading, isFalse);
    });

    test('toString contains phase info', () {
      final state = TriggerUiState.validating(TriggerType.inApp);
      final str = state.toString();
      expect(str, contains('validating'));
    });

    test('denied state preserves activeTriggerType from result', () {
      final result = TriggerResult.denied(
        requestId: 'ui-005',
        triggerType: TriggerType.notificationAction,
        denialReason: 'test',
        localizedResponse: 'test',
      );
      final state = TriggerUiState.denied(result);
      expect(state.activeTriggerType, equals(TriggerType.notificationAction));
    });
  });
}
