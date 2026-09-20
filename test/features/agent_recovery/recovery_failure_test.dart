/// recovery_failure_test.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Structural tests for RecoveryFailure model.
/// No Flutter/Dart SDK — structural/mock tests only.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_failure.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_failure_phase.dart';

void main() {
  group('RecoveryFailure', () {
    test('constructor creates failure with all fields', () {
      const failure = RecoveryFailure(
        message: 'Test failure',
        phase: RecoveryFailurePhase.screenParsing,
        originalError: 'parse error',
      );
      expect(failure.message, 'Test failure');
      expect(failure.phase, RecoveryFailurePhase.screenParsing);
      expect(failure.originalError, 'parse error');
    });

    test('copyWith preserves existing values', () {
      const failure = RecoveryFailure(
        message: 'Original',
        phase: RecoveryFailurePhase.llmCall,
      );
      final copied = failure.copyWith(message: 'Updated');
      expect(copied.message, 'Updated');
      expect(copied.phase, RecoveryFailurePhase.llmCall);
    });

    test('copyWith can update phase', () {
      const failure = RecoveryFailure(
        message: 'Test',
        phase: RecoveryFailurePhase.screenParsing,
      );
      final copied = failure.copyWith(
        phase: RecoveryFailurePhase.toolExecution,
      );
      expect(copied.phase, RecoveryFailurePhase.toolExecution);
      expect(copied.message, 'Test');
    });

    test('equality works for identical failures', () {
      const a = RecoveryFailure(
        message: 'Same',
        phase: RecoveryFailurePhase.llmCall,
      );
      const b = RecoveryFailure(
        message: 'Same',
        phase: RecoveryFailurePhase.llmCall,
      );
      expect(a, equals(b));
    });

    test('inequality for different phases', () {
      const a = RecoveryFailure(
        message: 'Same',
        phase: RecoveryFailurePhase.screenParsing,
      );
      const b = RecoveryFailure(
        message: 'Same',
        phase: RecoveryFailurePhase.llmCall,
      );
      expect(a, isNot(equals(b)));
    });

    test('hashCode consistency', () {
      const a = RecoveryFailure(
        message: 'Same',
        phase: RecoveryFailurePhase.screenParsing,
      );
      const b = RecoveryFailure(
        message: 'Same',
        phase: RecoveryFailurePhase.screenParsing,
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    test('RecoveryResult type alias is Result<T, RecoveryFailure>', () {
      // RecoveryResult<T> = Result<T, RecoveryFailure>
      // Verify it exists by using it in a type annotation
      final success = RecoveryResult<String>.success('ok');
      expect(success.isSuccess, true);
      expect(success.valueOrNull, 'ok');
    });

    test('RecoveryResult failure creation', () {
      const failure = RecoveryFailure(
        message: 'err',
        phase: RecoveryFailurePhase.userCancellation,
      );
      final result = RecoveryResult<String>.failure(failure);
      expect(result.isFailure, true);
      expect(result.failureOrNull, failure);
    });
  });
}
