/// default_recovery_executor_test.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Structural tests for DefaultRecoveryExecutor.
/// No Flutter/Dart SDK — structural/mock tests only.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/agent_recovery/infrastructure/default_recovery_executor.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_strategy.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_context.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_failure_phase.dart';

void main() {
  group('DefaultRecoveryExecutor', () {
    test('constructor creates executor', () {
      final executor = DefaultRecoveryExecutor();
      expect(executor, isA<DefaultRecoveryExecutor>());
    });

    test('implements RecoveryExecutor', () {
      final executor = DefaultRecoveryExecutor();
      // DefaultRecoveryExecutor implements RecoveryExecutor
      expect(executor, isA<RecoveryExecutor>());
    });

    test('isCancelled initially false', () {
      final executor = DefaultRecoveryExecutor();
      expect(executor.isCancelled, false);
    });

    test('cancel sets isCancelled to true', () {
      final executor = DefaultRecoveryExecutor();
      executor.cancel();
      expect(executor.isCancelled, true);
    });

    test('reset sets isCancelled back to false', () {
      final executor = DefaultRecoveryExecutor();
      executor.cancel();
      expect(executor.isCancelled, true);
      executor.reset();
      expect(executor.isCancelled, false);
    });

    test('executeStrategy returns RecoveryResult', () async {
      final executor = DefaultRecoveryExecutor();
      final context = RecoveryContext(
        stepIndex: 0,
        failedAction: 'tap',
        errorMessage: 'err',
        screenDescription: 'screen',
        failurePhase: RecoveryFailurePhase.toolExecution,
        errorTimestamp: 1000,
      );
      final result = await executor.executeStrategy(
        RecoveryStrategy.retrySameStep,
        context,
      );
      expect(result, isNotNull);
    });

    test('executeStrategy returns failure for abortSafely', () async {
      final executor = DefaultRecoveryExecutor();
      final context = RecoveryContext(
        stepIndex: 0,
        failedAction: 'tap',
        errorMessage: 'err',
        screenDescription: 'screen',
        failurePhase: RecoveryFailurePhase.unknown,
        errorTimestamp: 1000,
      );
      final result = await executor.executeStrategy(
        RecoveryStrategy.abortSafely,
        context,
      );
      expect(result.isFailure, true);
    });

    test('executeStrategy returns failure for noRecovery', () async {
      final executor = DefaultRecoveryExecutor();
      final context = RecoveryContext(
        stepIndex: 0,
        failedAction: 'tap',
        errorMessage: 'err',
        screenDescription: 'screen',
        failurePhase: RecoveryFailurePhase.unknown,
        errorTimestamp: 1000,
      );
      final result = await executor.executeStrategy(
        RecoveryStrategy.noRecovery,
        context,
      );
      expect(result.isFailure, true);
    });

    test('executeStrategy returns failure when cancelled', () async {
      final executor = DefaultRecoveryExecutor();
      executor.cancel();
      final context = RecoveryContext(
        stepIndex: 0,
        failedAction: 'tap',
        errorMessage: 'err',
        screenDescription: 'screen',
        failurePhase: RecoveryFailurePhase.toolExecution,
        errorTimestamp: 1000,
      );
      final result = await executor.executeStrategy(
        RecoveryStrategy.retrySameStep,
        context,
      );
      expect(result.isFailure, true);
    });
  });
}
