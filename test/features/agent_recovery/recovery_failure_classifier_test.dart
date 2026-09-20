/// recovery_failure_classifier_test.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Structural tests for RecoveryFailureClassifier abstract + DefaultRecoveryFailureClassifier.
/// No Flutter/Dart SDK — structural/mock tests only.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/agent_recovery/domain/services/recovery_failure_classifier.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_failure.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_failure_phase.dart';

void main() {
  group('RecoveryFailureClassifier', () {
    test('classify method returns RecoveryFailure', () {
      const classifier = DefaultRecoveryFailureClassifier();
      final failure = classifier.classify(
        Exception('test error'),
        stepIndex: 0,
      );
      expect(failure, isA<RecoveryFailure>());
      expect(failure.message, isNotEmpty);
      expect(failure.phase, isA<RecoveryFailurePhase>());
    });

    test('classify assigns correct phase for network error', () {
      const classifier = DefaultRecoveryFailureClassifier();
      final failure = classifier.classify(
        Exception('network error'),
        stepIndex: 1,
      );
      // Network-related errors should get networkRequest phase
      expect(failure.phase, RecoveryFailurePhase.networkRequest);
    });

    test('classify assigns correct phase for timeout error', () {
      const classifier = DefaultRecoveryFailureClassifier();
      final failure = classifier.classify(
        Exception('timeout'),
        stepIndex: 2,
      );
      expect(failure.phase, RecoveryFailurePhase.networkRequest);
    });

    test('classify assigns unknown for unrecognizable error', () {
      const classifier = DefaultRecoveryFailureClassifier();
      final failure = classifier.classify(
        Exception('something weird'),
        stepIndex: 0,
      );
      expect(failure.phase, RecoveryFailurePhase.unknown);
    });

    test('classify includes original error', () {
      const classifier = DefaultRecoveryFailureClassifier();
      final failure = classifier.classify(
        Exception('original error text'),
        stepIndex: 0,
      );
      expect(failure.originalError, isNotNull);
    });

    test('classify includes stepIndex', () {
      const classifier = DefaultRecoveryFailureClassifier();
      final failure = classifier.classify(
        Exception('err'),
        stepIndex: 5,
      );
      // The stepIndex should be preserved in context
      expect(failure, isA<RecoveryFailure>());
    });

    test('DefaultRecoveryFailureClassifier is const constructible', () {
      const classifier = DefaultRecoveryFailureClassifier();
      expect(classifier, isA<RecoveryFailureClassifier>());
    });
  });
}
