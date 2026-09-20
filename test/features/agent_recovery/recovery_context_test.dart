/// recovery_context_test.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Structural tests for RecoveryContext model.
/// No Flutter/Dart SDK — structural/mock tests only.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_context.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_failure_phase.dart';

void main() {
  group('RecoveryContext', () {
    test('constructor creates context with all fields', () {
      final context = RecoveryContext(
        stepIndex: 2,
        failedAction: 'tap_button',
        errorMessage: 'Button not found',
        screenDescription: 'Home screen',
        failurePhase: RecoveryFailurePhase.toolExecution,
        errorTimestamp: 1000,
      );
      expect(context.stepIndex, 2);
      expect(context.failedAction, 'tap_button');
      expect(context.errorMessage, 'Button not found');
      expect(context.screenDescription, 'Home screen');
      expect(context.failurePhase, RecoveryFailurePhase.toolExecution);
      expect(context.errorTimestamp, 1000);
    });

    test('copyWith preserves existing values', () {
      final context = RecoveryContext(
        stepIndex: 1,
        failedAction: 'scroll',
        errorMessage: 'Timeout',
        screenDescription: 'List',
        failurePhase: RecoveryFailurePhase.networkRequest,
        errorTimestamp: 500,
      );
      final copied = context.copyWith(errorMessage: 'Updated error');
      expect(copied.errorMessage, 'Updated error');
      expect(copied.stepIndex, 1);
      expect(copied.failedAction, 'scroll');
    });

    test('copyWith can update individual fields', () {
      final context = RecoveryContext(
        stepIndex: 0,
        failedAction: 'tap',
        errorMessage: 'err',
        screenDescription: 'scr',
        failurePhase: RecoveryFailurePhase.screenParsing,
        errorTimestamp: 0,
      );
      final copied = context.copyWith(stepIndex: 5);
      expect(copied.stepIndex, 5);
      expect(copied.failedAction, 'tap');
    });

    test('equality works for identical contexts', () {
      final a = RecoveryContext(
        stepIndex: 1,
        failedAction: 'tap',
        errorMessage: 'err',
        screenDescription: 'scr',
        failurePhase: RecoveryFailurePhase.llmCall,
        errorTimestamp: 100,
      );
      final b = RecoveryContext(
        stepIndex: 1,
        failedAction: 'tap',
        errorMessage: 'err',
        screenDescription: 'scr',
        failurePhase: RecoveryFailurePhase.llmCall,
        errorTimestamp: 100,
      );
      expect(a, equals(b));
    });

    test('inequality for different stepIndex', () {
      final a = RecoveryContext(
        stepIndex: 1,
        failedAction: 'tap',
        errorMessage: 'err',
        screenDescription: 'scr',
        failurePhase: RecoveryFailurePhase.llmCall,
        errorTimestamp: 100,
      );
      final b = RecoveryContext(
        stepIndex: 2,
        failedAction: 'tap',
        errorMessage: 'err',
        screenDescription: 'scr',
        failurePhase: RecoveryFailurePhase.llmCall,
        errorTimestamp: 100,
      );
      expect(a, isNot(equals(b)));
    });

    test('hashCode consistency', () {
      final a = RecoveryContext(
        stepIndex: 1,
        failedAction: 'tap',
        errorMessage: 'err',
        screenDescription: 'scr',
        failurePhase: RecoveryFailurePhase.llmCall,
        errorTimestamp: 100,
      );
      final b = RecoveryContext(
        stepIndex: 1,
        failedAction: 'tap',
        errorMessage: 'err',
        screenDescription: 'scr',
        failurePhase: RecoveryFailurePhase.llmCall,
        errorTimestamp: 100,
      );
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
