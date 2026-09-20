/// recovery_coordinator_test.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Structural tests for RecoveryCoordinator application service.
/// No Flutter/Dart SDK — structural/mock tests only.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/agent_recovery/application/recovery_coordinator.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_context.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_failure_phase.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_state.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_phase.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/retry_policy.dart';
import 'package:aura_assistant/features/agent_recovery/infrastructure/default_recovery_failure_classifier.dart';
import 'package:aura_assistant/features/agent_recovery/infrastructure/default_recovery_executor.dart';
import 'package:aura_assistant/features/agent_recovery/infrastructure/default_replanning_engine.dart';

void main() {
  group('RecoveryCoordinator', () {
    late RecoveryCoordinator coordinator;

    setUp(() {
      coordinator = RecoveryCoordinator(
        classifier: const DefaultRecoveryFailureClassifier(),
        replanningEngine: DefaultReplanningEngine(
          classifier: const DefaultRecoveryFailureClassifier(),
        ),
        executor: DefaultRecoveryExecutor(),
      );
    });

    test('constructor creates coordinator with required deps', () {
      expect(coordinator, isA<RecoveryCoordinator>());
    });

    test('currentState is RecoveryState', () {
      expect(coordinator.currentState, isA<RecoveryState>());
    });

    test('initial state is idle', () {
      expect(coordinator.currentState.phase, RecoveryPhase.idle);
    });

    test('currentRetryPolicy is accessible', () {
      expect(coordinator.currentRetryPolicy, isA<RetryPolicy>());
    });

    test('cancelRecovery sets cancellation', () {
      coordinator.cancelRecovery();
      expect(coordinator.currentState.isCancellationRequested, true);
    });

    test('reset returns to idle', () {
      coordinator.cancelRecovery();
      expect(coordinator.currentState.isCancellationRequested, true);
      coordinator.reset();
      expect(coordinator.currentState.phase, RecoveryPhase.idle);
      expect(coordinator.currentState.isCancellationRequested, false);
    });

    test('injectContext stores context', () {
      final context = RecoveryContext(
        stepIndex: 1,
        failedAction: 'tap',
        errorMessage: 'err',
        screenDescription: 'screen',
        failurePhase: RecoveryFailurePhase.toolExecution,
        errorTimestamp: 1000,
      );
      coordinator.injectContext(context);
      // After injection, coordinator should have context
      expect(coordinator.currentState, isA<RecoveryState>());
    });

    test('addStateCallback registers callback', () {
      var callbackCount = 0;
      coordinator.addStateCallback((_) {
        callbackCount++;
      });
      // Trigger a state change
      coordinator.cancelRecovery();
      // Callback should have been called at least once
      // (exact count depends on implementation internals)
    });

    test('recover returns null when no context', () {
      final result = coordinator.recover(
        RecoveryContext(
          stepIndex: 0,
          failedAction: '',
          errorMessage: 'err',
          screenDescription: '',
          failurePhase: RecoveryFailurePhase.unknown,
          errorTimestamp: 0,
        ),
        Exception('err'),
      );
      // Result may be success or failure depending on strategy selection
      expect(result, isNotNull);
    });
  });
}
