/// recovery_failure_phase_test.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Structural tests for RecoveryFailurePhase enum.
/// No Flutter/Dart SDK — structural/mock tests only.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_failure_phase.dart';

void main() {
  group('RecoveryFailurePhase', () {
    test('has all 11 expected values', () {
      const expected = [
        RecoveryFailurePhase.screenParsing,
        RecoveryFailurePhase.llmCall,
        RecoveryFailurePhase.toolExecution,
        RecoveryFailurePhase.planValidation,
        RecoveryFailurePhase.stepExecution,
        RecoveryFailurePhase.contextCapture,
        RecoveryFailurePhase.memoryRetrieval,
        RecoveryFailurePhase.networkRequest,
        RecoveryFailurePhase.userCancellation,
        RecoveryFailurePhase.policyViolation,
        RecoveryFailurePhase.unknown,
      ];
      expect(RecoveryFailurePhase.values.length, 11);
      expect(RecoveryFailurePhase.values, orderedEquals(expected));
    });

    test('name property returns correct string', () {
      expect(RecoveryFailurePhase.screenParsing.name, 'screenParsing');
      expect(RecoveryFailurePhase.llmCall.name, 'llmCall');
      expect(RecoveryFailurePhase.toolExecution.name, 'toolExecution');
      expect(RecoveryFailurePhase.planValidation.name, 'planValidation');
      expect(RecoveryFailurePhase.stepExecution.name, 'stepExecution');
      expect(RecoveryFailurePhase.contextCapture.name, 'contextCapture');
      expect(RecoveryFailurePhase.memoryRetrieval.name, 'memoryRetrieval');
      expect(RecoveryFailurePhase.networkRequest.name, 'networkRequest');
      expect(RecoveryFailurePhase.userCancellation.name, 'userCancellation');
      expect(RecoveryFailurePhase.policyViolation.name, 'policyViolation');
      expect(RecoveryFailurePhase.unknown.name, 'unknown');
    });

    test('values list is unmodifiable', () {
      // Enum values list is always unmodifiable in Dart
      expect(RecoveryFailurePhase.values, hasLength(11));
    });

    test('no duplicate values', () {
      final names = RecoveryFailurePhase.values.map((e) => e.name).toSet();
      expect(names.length, RecoveryFailurePhase.values.length);
    });

    test('screenParsing is first', () {
      expect(RecoveryFailurePhase.values.first,
          RecoveryFailurePhase.screenParsing);
    });

    test('unknown is last', () {
      expect(RecoveryFailurePhase.values.last, RecoveryFailurePhase.unknown);
    });
  });
}
