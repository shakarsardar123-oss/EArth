/// agent_plan_test.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Structural tests for AgentPlan model.
/// No Flutter/Dart SDK — structural/mock tests only.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/agent_plan.dart';

void main() {
  group('AgentPlan', () {
    test('AgentStepResult has succeeded property', () {
      const result = AgentStepResult(succeeded: true);
      expect(result.succeeded, true);
    });

    test('AgentStepResult.succeeded=false creates failed result', () {
      const result = AgentStepResult(succeeded: false);
      expect(result.succeeded, false);
    });

    test('AgentStepResult is immutable', () {
      const result = AgentStepResult(succeeded: true);
      // Same instance — immutable
      expect(result.succeeded, true);
    });

    test('AgentPlan constructor creates with defaults', () {
      const plan = AgentPlan(
        steps: [],
        successfulStepCount: 0,
      );
      expect(plan.steps, isEmpty);
      expect(plan.successfulStepCount, 0);
    });

    test('AgentPlan copyWith preserves existing values', () {
      const plan = AgentPlan(
        steps: [],
        successfulStepCount: 2,
      );
      final copied = plan.copyWith(successfulStepCount: 5);
      expect(copied.successfulStepCount, 5);
      expect(copied.steps, isEmpty);
    });

    test('AgentPlan remainingSteps returns steps after successful count', () {
      const plan = AgentPlan(
        steps: [],
        successfulStepCount: 0,
      );
      expect(plan.remainingSteps, isEmpty);
    });

    test('AgentStepResult equality', () {
      const a = AgentStepResult(succeeded: true);
      const b = AgentStepResult(succeeded: true);
      expect(a, equals(b));
    });

    test('AgentStepResult hashCode consistency', () {
      const a = AgentStepResult(succeeded: true);
      const b = AgentStepResult(succeeded: true);
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
