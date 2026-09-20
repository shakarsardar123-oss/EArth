/// recovery_state_test.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Structural tests for RecoveryState model.
/// No Flutter/Dart SDK — structural/mock tests only.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_state.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_phase.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_strategy.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/retry_policy.dart';

void main() {
  group('RecoveryState', () {
    test('default constructor creates idle state', () {
      const state = RecoveryState();
      expect(state.phase, RecoveryPhase.idle);
      expect(state.currentRetryCount, 0);
      expect(state.hasRetriesExhausted, false);
      expect(state.isCancellationRequested, false);
    });

    test('copyWith preserves existing values', () {
      const state = RecoveryState();
      final copied = state.copyWith(currentRetryCount: 3);
      expect(copied.currentRetryCount, 3);
      expect(copied.phase, RecoveryPhase.idle);
      expect(copied.isCancellationRequested, false);
    });

    test('copyWith can update phase', () {
      const state = RecoveryState();
      final copied = state.copyWith(phase: RecoveryPhase.classifying);
      expect(copied.phase, RecoveryPhase.classifying);
      expect(copied.currentRetryCount, 0);
    });

    test('copyWith can update currentStrategy', () {
      const state = RecoveryState();
      final copied = state.copyWith(
        currentStrategy: RecoveryStrategy.retrySameStep,
      );
      expect(copied.currentStrategy, RecoveryStrategy.retrySameStep);
    });

    test('hasRetriesExhausted respects max limits', () {
      const state = RecoveryState(currentRetryCount: 10);
      // Default maxTotalRetries = 10, so 10 means exhausted
      expect(state.hasRetriesExhausted, true);
    });

    test('hasRetriesExhausted false below limit', () {
      const state = RecoveryState(currentRetryCount: 5);
      expect(state.hasRetriesExhausted, false);
    });

    test('isCancellationRequested defaults to false', () {
      const state = RecoveryState();
      expect(state.isCancellationRequested, false);
    });

    test('copyWith can set cancellation', () {
      const state = RecoveryState();
      final cancelled = state.copyWith(isCancellationRequested: true);
      expect(cancelled.isCancellationRequested, true);
    });

    test('retryPolicy is accessible', () {
      const state = RecoveryState();
      expect(state.retryPolicy, isA<RetryPolicy>());
    });

    test('equality works for identical states', () {
      const a = RecoveryState();
      const b = RecoveryState();
      expect(a, equals(b));
    });

    test('copyWith updates completedStepCount', () {
      const state = RecoveryState();
      final updated = state.copyWith(completedStepCount: 3);
      expect(updated.completedStepCount, 3);
    });

    test('copyWith updates remainingStepCount', () {
      const state = RecoveryState();
      final updated = state.copyWith(remainingStepCount: 7);
      expect(updated.remainingStepCount, 7);
    });
  });
}
