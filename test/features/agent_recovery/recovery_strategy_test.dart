/// recovery_strategy_test.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Structural tests for RecoveryStrategy enum.
/// No Flutter/Dart SDK — structural/mock tests only.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_strategy.dart';

void main() {
  group('RecoveryStrategy', () {
    test('has all 10 expected values', () {
      const expected = [
        RecoveryStrategy.retrySameStep,
        RecoveryStrategy.retryModifiedStep,
        RecoveryStrategy.recaptureScreen,
        RecoveryStrategy.reunderstandScreen,
        RecoveryStrategy.replanFromCurrentStep,
        RecoveryStrategy.replanFromScratch,
        RecoveryStrategy.skipStepAndContinue,
        RecoveryStrategy.abortSafely,
        RecoveryStrategy.escalateToUser,
        RecoveryStrategy.noRecovery,
      ];
      expect(RecoveryStrategy.values.length, 10);
      expect(RecoveryStrategy.values, orderedEquals(expected));
    });

    test('name property returns correct string', () {
      expect(RecoveryStrategy.retrySameStep.name, 'retrySameStep');
      expect(RecoveryStrategy.retryModifiedStep.name, 'retryModifiedStep');
      expect(RecoveryStrategy.recaptureScreen.name, 'recaptureScreen');
      expect(RecoveryStrategy.reunderstandScreen.name, 'reunderstandScreen');
      expect(
          RecoveryStrategy.replanFromCurrentStep.name, 'replanFromCurrentStep');
      expect(RecoveryStrategy.replanFromScratch.name, 'replanFromScratch');
      expect(
          RecoveryStrategy.skipStepAndContinue.name, 'skipStepAndContinue');
      expect(RecoveryStrategy.abortSafely.name, 'abortSafely');
      expect(RecoveryStrategy.escalateToUser.name, 'escalateToUser');
      expect(RecoveryStrategy.noRecovery.name, 'noRecovery');
    });

    test('no duplicate values', () {
      final names = RecoveryStrategy.values.map((e) => e.name).toSet();
      expect(names.length, RecoveryStrategy.values.length);
    });

    test('retrySameStep is first', () {
      expect(RecoveryStrategy.values.first, RecoveryStrategy.retrySameStep);
    });

    test('noRecovery is last', () {
      expect(RecoveryStrategy.values.last, RecoveryStrategy.noRecovery);
    });
  });
}
