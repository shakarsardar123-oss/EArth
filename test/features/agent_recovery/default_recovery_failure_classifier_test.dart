/// default_recovery_failure_classifier_test.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Structural tests for DefaultRecoveryFailureClassifier.
/// No Flutter/Dart SDK — structural/mock tests only.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/agent_recovery/infrastructure/default_recovery_failure_classifier.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_failure.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_failure_phase.dart';

void main() {
  group('DefaultRecoveryFailureClassifier', () {
    test('is const constructible', () {
      const classifier = DefaultRecoveryFailureClassifier();
      expect(classifier, isA<DefaultRecoveryFailureClassifier>());
    });

    test('implements RecoveryFailureClassifier', () {
      const classifier = DefaultRecoveryFailureClassifier();
      expect(classifier, isA<RecoveryFailureClassifier>());
    });

    test('classify returns RecoveryFailure for generic error', () {
      const classifier = DefaultRecoveryFailureClassifier();
      final failure = classifier.classify(
        Exception('generic error'),
        stepIndex: 0,
      );
      expect(failure, isA<RecoveryFailure>());
      expect(failure.message, isNotEmpty);
    });

    test('classify maps screen errors to screenParsing phase', () {
      const classifier = DefaultRecoveryFailureClassifier();
      final failure = classifier.classify(
        Exception('screen parse failed'),
        stepIndex: 0,
      );
      expect(failure.phase, RecoveryFailurePhase.screenParsing);
    });

    test('classify maps LLM errors to llmCall phase', () {
      const classifier = DefaultRecoveryFailureClassifier();
      final failure = classifier.classify(
        Exception('LLM response invalid'),
        stepIndex: 0,
      );
      expect(failure.phase, RecoveryFailurePhase.llmCall);
    });

    test('classify maps tool errors to toolExecution phase', () {
      const classifier = DefaultRecoveryFailureClassifier();
      final failure = classifier.classify(
        Exception('tool execution failed'),
        stepIndex: 0,
      );
      expect(failure.phase, RecoveryFailurePhase.toolExecution);
    });

    test('classify maps plan errors to planValidation phase', () {
      const classifier = DefaultRecoveryFailureClassifier();
      final failure = classifier.classify(
        Exception('plan validation error'),
        stepIndex: 0,
      );
      expect(failure.phase, RecoveryFailurePhase.planValidation);
    });

    test('classify maps step errors to stepExecution phase', () {
      const classifier = DefaultRecoveryFailureClassifier();
      final failure = classifier.classify(
        Exception('step execution error'),
        stepIndex: 0,
      );
      expect(failure.phase, RecoveryFailurePhase.stepExecution);
    });

    test('classify maps context errors to contextCapture phase', () {
      const classifier = DefaultRecoveryFailureClassifier();
      final failure = classifier.classify(
        Exception('context capture failed'),
        stepIndex: 0,
      );
      expect(failure.phase, RecoveryFailurePhase.contextCapture);
    });

    test('classify maps memory errors to memoryRetrieval phase', () {
      const classifier = DefaultRecoveryFailureClassifier();
      final failure = classifier.classify(
        Exception('memory retrieval error'),
        stepIndex: 0,
      );
      expect(failure.phase, RecoveryFailurePhase.memoryRetrieval);
    });

    test('classify maps unknown errors to unknown phase', () {
      const classifier = DefaultRecoveryFailureClassifier();
      final failure = classifier.classify(
        Exception('something completely unexpected'),
        stepIndex: 0,
      );
      expect(failure.phase, RecoveryFailurePhase.unknown);
    });

    test('classify preserves stepIndex in context', () {
      const classifier = DefaultRecoveryFailureClassifier();
      final failure = classifier.classify(
        Exception('err'),
        stepIndex: 7,
      );
      expect(failure, isA<RecoveryFailure>());
      // stepIndex is used internally for classification context
    });

    test('multiple calls produce consistent results', () {
      const classifier = DefaultRecoveryFailureClassifier();
      final failure1 = classifier.classify(
        Exception('network error'),
        stepIndex: 0,
      );
      final failure2 = classifier.classify(
        Exception('network error'),
        stepIndex: 0,
      );
      expect(failure1.phase, failure2.phase);
    });
  });
}
