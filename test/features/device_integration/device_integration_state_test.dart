/// Tests for DeviceIntegrationState and DeviceIntegrationProcessingState.
/// Covers: copyWith clear flags, isProcessing, isIdle, totalProcessed.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/device_integration/application/device_integration_state.dart';
import 'package:aura_assistant/features/device_integration/domain/entities/device_action.dart';
import 'package:aura_assistant/features/device_integration/domain/models/device_integration_failure.dart';

void main() {
  // ─── DeviceIntegrationProcessingState ────────────────────────────
  group('DeviceIntegrationProcessingState', () {
    test('has all seven states', () {
      expect(DeviceIntegrationProcessingState.values.length, 7);
      expect(DeviceIntegrationProcessingState.values,
          contains(DeviceIntegrationProcessingState.idle));
      expect(DeviceIntegrationProcessingState.values,
          contains(DeviceIntegrationProcessingState.validating));
      expect(DeviceIntegrationProcessingState.values,
          contains(DeviceIntegrationProcessingState.awaitingPermission));
      expect(DeviceIntegrationProcessingState.values,
          contains(DeviceIntegrationProcessingState.executing));
      expect(DeviceIntegrationProcessingState.values,
          contains(DeviceIntegrationProcessingState.verifying));
      expect(DeviceIntegrationProcessingState.values,
          contains(DeviceIntegrationProcessingState.success));
      expect(DeviceIntegrationProcessingState.values,
          contains(DeviceIntegrationProcessingState.failure));
    });
  });

  // ─── DeviceIntegrationState defaults ──────────────────────────────
  group('DeviceIntegrationState defaults', () {
    test('initial state is idle', () {
      const state = DeviceIntegrationState();
      expect(state.processingState, DeviceIntegrationProcessingState.idle);
      expect(state.isIdle, isTrue);
      expect(state.isProcessing, isFalse);
    });

    test('initial counters are zero', () {
      const state = DeviceIntegrationState();
      expect(state.successCount, 0);
      expect(state.failureCount, 0);
      expect(state.securityRejectionCount, 0);
      expect(state.totalProcessed, 0);
    });

    test('initial collections are empty', () {
      const state = DeviceIntegrationState();
      expect(state.actionQueue, isEmpty);
      expect(state.currentAction, isNull);
      expect(state.lastCompletedAction, isNull);
      expect(state.lastError, isNull);
      expect(state.warning, isNull);
    });
  });

  // ─── isProcessing / isIdle ──────────────────────────────────────
  group('isProcessing and isIdle', () {
    test('idle state is idle and not processing', () {
      const state = DeviceIntegrationState(
        processingState: DeviceIntegrationProcessingState.idle,
      );
      expect(state.isIdle, isTrue);
      expect(state.isProcessing, isFalse);
    });

    test('validating state is processing and not idle', () {
      const state = DeviceIntegrationState(
        processingState: DeviceIntegrationProcessingState.validating,
      );
      expect(state.isIdle, isFalse);
      expect(state.isProcessing, isTrue);
    });

    test('executing state is processing', () {
      const state = DeviceIntegrationState(
        processingState: DeviceIntegrationProcessingState.executing,
      );
      expect(state.isProcessing, isTrue);
    });

    test('success state is not processing and not idle', () {
      const state = DeviceIntegrationState(
        processingState: DeviceIntegrationProcessingState.success,
      );
      expect(state.isProcessing, isFalse);
      expect(state.isIdle, isFalse);
    });

    test('failure state is not processing and not idle', () {
      const state = DeviceIntegrationState(
        processingState: DeviceIntegrationProcessingState.failure,
      );
      expect(state.isProcessing, isFalse);
      expect(state.isIdle, isFalse);
    });
  });

  // ─── totalProcessed ─────────────────────────────────────────────
  group('totalProcessed', () {
    test('is sum of successCount and failureCount', () {
      const state = DeviceIntegrationState(
        successCount: 3,
        failureCount: 2,
      );
      expect(state.totalProcessed, 5);
    });

    test('is zero when both counts are zero', () {
      const state = DeviceIntegrationState();
      expect(state.totalProcessed, 0);
    });
  });

  // ─── copyWith ──────────────────────────────────────────────────
  group('DeviceIntegrationState.copyWith', () {
    test('updates processingState', () {
      const state = DeviceIntegrationState();
      final updated = state.copyWith(
        processingState: DeviceIntegrationProcessingState.executing,
      );
      expect(updated.processingState,
          DeviceIntegrationProcessingState.executing);
    });

    test('increments successCount', () {
      const state = DeviceIntegrationState();
      final updated = state.copyWith(successCount: 1);
      expect(updated.successCount, 1);
    });

    test('increments failureCount', () {
      const state = DeviceIntegrationState();
      final updated = state.copyWith(failureCount: 1);
      expect(updated.failureCount, 1);
    });

    test('sets currentAction', () {
      const state = DeviceIntegrationState();
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final updated = state.copyWith(currentAction: action);
      expect(updated.currentAction, isNotNull);
      expect(updated.currentAction!.type, DeviceActionType.tap);
    });

    test('sets lastError', () {
      const state = DeviceIntegrationState();
      final error = DeviceIntegrationFailure.permission('denied');
      final updated = state.copyWith(lastError: error);
      expect(updated.lastError, isNotNull);
      expect(updated.lastError!.phase, DeviceIntegrationFailurePhase.permission);
    });

    test('sets warning', () {
      const state = DeviceIntegrationState();
      final updated = state.copyWith(warning: 'low confidence');
      expect(updated.warning, 'low confidence');
    });
  });

  // ─── copyWith clear flags ──────────────────────────────────────
  group('DeviceIntegrationState.copyWith clear flags', () {
    test('clearError clears lastError', () {
      final state = DeviceIntegrationState(
        lastError: DeviceIntegrationFailure.validation('err'),
      );
      final updated = state.copyWith(clearError: true);
      expect(updated.lastError, isNull);
    });

    test('clearWarning clears warning', () {
      const state = DeviceIntegrationState(warning: 'warn');
      final updated = state.copyWith(clearWarning: true);
      expect(updated.warning, isNull);
    });

    test('clearCurrentAction clears currentAction', () {
      final state = DeviceIntegrationState(
        currentAction: DeviceAction.tap(
          targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
        ),
      );
      final updated = state.copyWith(clearCurrentAction: true);
      expect(updated.currentAction, isNull);
    });

    test('clearLastCompletedAction clears lastCompletedAction', () {
      final state = DeviceIntegrationState(
        lastCompletedAction: DeviceAction.back(),
      );
      final updated = state.copyWith(clearLastCompletedAction: true);
      expect(updated.lastCompletedAction, isNull);
    });

    test('clear flags do not affect other fields', () {
      final state = DeviceIntegrationState(
        lastError: DeviceIntegrationFailure.validation('err'),
        warning: 'warn',
        successCount: 5,
      );
      final updated = state.copyWith(
        clearError: true,
        clearWarning: true,
      );
      expect(updated.lastError, isNull);
      expect(updated.warning, isNull);
      expect(updated.successCount, 5);
    });
  });
}
