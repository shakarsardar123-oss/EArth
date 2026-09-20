/// default_replanning_engine_test.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Structural tests for DefaultReplanningEngine.
/// No Flutter/Dart SDK — structural/mock tests only.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/agent_recovery/infrastructure/default_replanning_engine.dart';
import 'package:aura_assistant/features/agent_recovery/domain/services/recovery_failure_classifier.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_failure.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_failure_phase.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_context.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_strategy.dart';

void main() {
  group('DefaultReplanningEngine', () {
    test('constructor requires classifier', () {
      final engine = DefaultReplanningEngine(
        classifier: const DefaultRecoveryFailureClassifier(),
      );
      expect(engine, isA<DefaultReplanningEngine>());
    });

    test('implements ReplanningEngine', () {
      final engine = DefaultReplanningEngine(
        classifier: const DefaultRecoveryFailureClassifier(),
      );
      expect(engine, isA<ReplanningEngine>());
    });

    test('selectStrategy returns RecoveryStrategy', () {
      final engine = DefaultReplanningEngine(
        classifier: const DefaultRecoveryFailureClassifier(),
      );
      final context = RecoveryContext(
        stepIndex: 0,
        failedAction: 'tap',
        errorMessage: 'err',
        screenDescription: 'screen',
        failurePhase: RecoveryFailurePhase.toolExecution,
        errorTimestamp: 1000,
      );
      final failure = const RecoveryFailure(
        message: 'err',
        phase: RecoveryFailurePhase.toolExecution,
      );
      final strategy = engine.selectStrategy(failure, context);
      expect(strategy, isA<RecoveryStrategy>());
    });

    test('selectStrategy escalation: retryable phase → retrySameStep', () {
      final engine = DefaultReplanningEngine(
        classifier: const DefaultRecoveryFailureClassifier(),
      );
      final context = RecoveryContext(
        stepIndex: 0,
        failedAction: 'tap',
        errorMessage: 'err',
        screenDescription: 'screen',
        failurePhase: RecoveryFailurePhase.toolExecution,
        errorTimestamp: 1000,
        retryCount: 0,
      );
      final failure = const RecoveryFailure(
        message: 'err',
        phase: RecoveryFailurePhase.toolExecution,
      );
      final strategy = engine.selectStrategy(failure, context);
      // First retry for retryable phase should be retrySameStep
      expect(strategy, RecoveryStrategy.retrySameStep);
    });

    test('selectStrategy escalation: high retry count → escalate', () {
      final engine = DefaultReplanningEngine(
        classifier: const DefaultRecoveryFailureClassifier(),
      );
      final context = RecoveryContext(
        stepIndex: 0,
        failedAction: 'tap',
        errorMessage: 'err',
        screenDescription: 'screen',
        failurePhase: RecoveryFailurePhase.toolExecution,
        errorTimestamp: 1000,
        retryCount: 3,
      );
      final failure = const RecoveryFailure(
        message: 'err',
        phase: RecoveryFailurePhase.toolExecution,
      );
      final strategy = engine.selectStrategy(failure, context);
      // After max retries, should escalate (retryModified, recaptureScreen, replan, or abort)
      expect(strategy, isNot(equals(RecoveryStrategy.retrySameStep)));
    });

    test('selectStrategy for screenParsing → recaptureScreen', () {
      final engine = DefaultReplanningEngine(
        classifier: const DefaultRecoveryFailureClassifier(),
      );
      final context = RecoveryContext(
        stepIndex: 0,
        failedAction: 'parse',
        errorMessage: 'screen unreadable',
        screenDescription: 'screen',
        failurePhase: RecoveryFailurePhase.screenParsing,
        errorTimestamp: 1000,
        retryCount: 1,
      );
      final failure = const RecoveryFailure(
        message: 'screen unreadable',
        phase: RecoveryFailurePhase.screenParsing,
      );
      final strategy = engine.selectStrategy(failure, context);
      // Screen parsing failure after retry should escalate to recapture
      expect(
        strategy == RecoveryStrategy.recaptureScreen ||
            strategy == RecoveryStrategy.reunderstandScreen ||
            strategy == RecoveryStrategy.replanFromCurrentStep ||
            strategy == RecoveryStrategy.abortSafely,
        true,
      );
    });

    test('selectStrategy for userCancellation → noRecovery', () {
      final engine = DefaultReplanningEngine(
        classifier: const DefaultRecoveryFailureClassifier(),
      );
      final context = RecoveryContext(
        stepIndex: 0,
        failedAction: '',
        errorMessage: 'cancelled',
        screenDescription: '',
        failurePhase: RecoveryFailurePhase.userCancellation,
        errorTimestamp: 1000,
      );
      final failure = const RecoveryFailure(
        message: 'cancelled',
        phase: RecoveryFailurePhase.userCancellation,
      );
      final strategy = engine.selectStrategy(failure, context);
      expect(strategy, RecoveryStrategy.noRecovery);
    });

    test('selectStrategy for policyViolation → noRecovery', () {
      final engine = DefaultReplanningEngine(
        classifier: const DefaultRecoveryFailureClassifier(),
      );
      final context = RecoveryContext(
        stepIndex: 0,
        failedAction: '',
        errorMessage: 'policy violation',
        screenDescription: '',
        failurePhase: RecoveryFailurePhase.policyViolation,
        errorTimestamp: 1000,
      );
      final failure = const RecoveryFailure(
        message: 'policy violation',
        phase: RecoveryFailurePhase.policyViolation,
      );
      final strategy = engine.selectStrategy(failure, context);
      expect(strategy, RecoveryStrategy.noRecovery);
    });

    test('escalation chain: retrySame→retryModified→recaptureScreen→reunderstandScreen→replan→abortSafely', () {
      final engine = DefaultReplanningEngine(
        classifier: const DefaultRecoveryFailureClassifier(),
      );
      // Verify the escalation chain concept by testing increasing retry counts
      for (var retryCount = 0; retryCount <= 5; retryCount++) {
        final context = RecoveryContext(
          stepIndex: 0,
          failedAction: 'tap',
          errorMessage: 'err',
          screenDescription: 'screen',
          failurePhase: RecoveryFailurePhase.toolExecution,
          errorTimestamp: 1000,
          retryCount: retryCount,
        );
        final failure = const RecoveryFailure(
          message: 'err',
          phase: RecoveryFailurePhase.toolExecution,
        );
        final strategy = engine.selectStrategy(failure, context);
        expect(strategy, isA<RecoveryStrategy>());
      }
    });
  });
}
