/// recovery_phase_test.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Structural tests for RecoveryPhase enum.
/// No Flutter/Dart SDK — structural/mock tests only.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_phase.dart';

void main() {
  group('RecoveryPhase', () {
    test('has all 11 expected values', () {
      const expected = [
        RecoveryPhase.idle,
        RecoveryPhase.detecting,
        RecoveryPhase.classifying,
        RecoveryPhase.selectingStrategy,
        RecoveryPhase.executingStrategy,
        RecoveryPhase.retryingStep,
        RecoveryPhase.replanning,
        RecoveryPhase.recapturingScreen,
        RecoveryPhase.reunderstandingScreen,
        RecoveryPhase.verifying,
        RecoveryPhase.aborting,
      ];
      expect(RecoveryPhase.values.length, 11);
      expect(RecoveryPhase.values, orderedEquals(expected));
    });

    test('name property returns correct string', () {
      expect(RecoveryPhase.idle.name, 'idle');
      expect(RecoveryPhase.detecting.name, 'detecting');
      expect(RecoveryPhase.classifying.name, 'classifying');
      expect(RecoveryPhase.selectingStrategy.name, 'selectingStrategy');
      expect(RecoveryPhase.executingStrategy.name, 'executingStrategy');
      expect(RecoveryPhase.retryingStep.name, 'retryingStep');
      expect(RecoveryPhase.replanning.name, 'replanning');
      expect(RecoveryPhase.recapturingScreen.name, 'recapturingScreen');
      expect(RecoveryPhase.reunderstandingScreen.name, 'reunderstandingScreen');
      expect(RecoveryPhase.verifying.name, 'verifying');
      expect(RecoveryPhase.aborting.name, 'aborting');
    });

    test('no duplicate values', () {
      final names = RecoveryPhase.values.map((e) => e.name).toSet();
      expect(names.length, RecoveryPhase.values.length);
    });

    test('idle is first', () {
      expect(RecoveryPhase.values.first, RecoveryPhase.idle);
    });

    test('aborting is last', () {
      expect(RecoveryPhase.values.last, RecoveryPhase.aborting);
    });

    test('idle is the initial/default phase', () {
      expect(RecoveryPhase.idle.index, 0);
    });
  });
}
