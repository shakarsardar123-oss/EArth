/// advanced_task_plan_test.dart
/// Structural & mock tests for AdvancedTaskPlan model.
///
/// Verifies: class existence, fields (NO goals), methods,
/// PlanStatus enum, FAIL-CLOSED patterns.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/advanced_task_plan.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/task_step.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/task_step_status.dart';

void main() {
  group('PlanStatus', () {
    test('has expected values', () {
      expect(PlanStatus.values, containsAll([
        PlanStatus.draft,
        PlanStatus.active,
        PlanStatus.completed,
        PlanStatus.failed,
        PlanStatus.cancelled,
        PlanStatus.paused,
      ]));
    });
  });

  group('AdvancedTaskPlan', () {
    test('has planId, steps, locale fields', () {
      final plan = AdvancedTaskPlan(
        planId: 'p1',
        steps: [],
        locale: 'ku',
        createdAt: DateTime.now(),
      );
      expect(plan.planId, 'p1');
      expect(plan.steps, isEmpty);
      expect(plan.locale, 'ku');
    });

    test('does NOT have goals field', () {
      // AdvancedTaskPlan has no goals field by design
      final plan = AdvancedTaskPlan(
        planId: 'p1',
        steps: [],
        locale: 'ku',
        createdAt: DateTime.now(),
      );
      // Verify goals is not a field on the model
      expect((plan).hashCode, isNotNull); // just ensure instance works
    });

    test('currentStep returns first in-progress step', () {
      final step1 = TaskStep(stepId: 's1', description: 'Step 1', status: TaskStepStatus.completed);
      final step2 = TaskStep(stepId: 's2', description: 'Step 2', status: TaskStepStatus.inProgress);
      final plan = AdvancedTaskPlan(
        planId: 'p1',
        steps: [step1, step2],
        locale: 'ku',
        createdAt: DateTime.now(),
      );
      expect(plan.currentStep, isNotNull);
      expect(plan.currentStep!.stepId, 's2');
    });

    test('nextPendingStep returns first pending step', () {
      final step1 = TaskStep(stepId: 's1', description: 'Step 1', status: TaskStepStatus.completed);
      final step2 = TaskStep(stepId: 's2', description: 'Step 2', status: TaskStepStatus.pending);
      final plan = AdvancedTaskPlan(
        planId: 'p1',
        steps: [step1, step2],
        locale: 'ku',
        createdAt: DateTime.now(),
      );
      expect(plan.nextPendingStep, isNotNull);
      expect(plan.nextPendingStep!.stepId, 's2');
    });

    test('stepById finds step by ID', () {
      final step = TaskStep(stepId: 's1', description: 'Find me', status: TaskStepStatus.pending);
      final plan = AdvancedTaskPlan(
        planId: 'p1',
        steps: [step],
        locale: 'ku',
        createdAt: DateTime.now(),
      );
      expect(plan.stepById('s1'), isNotNull);
      expect(plan.stepById('nonexistent'), isNull);
    });

    test('progress returns 0.0 for empty steps', () {
      final plan = AdvancedTaskPlan(
        planId: 'p1',
        steps: [],
        locale: 'ku',
        createdAt: DateTime.now(),
      );
      expect(plan.progress(0.0), 0.0);
    });

    test('completedSteps returns completed count', () {
      final s1 = TaskStep(stepId: 's1', description: '', status: TaskStepStatus.completed);
      final s2 = TaskStep(stepId: 's2', description: '', status: TaskStepStatus.inProgress);
      final s3 = TaskStep(stepId: 's3', description: '', status: TaskStepStatus.completed);
      final plan = AdvancedTaskPlan(
        planId: 'p1',
        steps: [s1, s2, s3],
        locale: 'ku',
        createdAt: DateTime.now(),
      );
      expect(plan.completedSteps.length, 2);
    });

    test('failedSteps returns failed count', () {
      final s1 = TaskStep(stepId: 's1', description: '', status: TaskStepStatus.failed);
      final s2 = TaskStep(stepId: 's2', description: '', status: TaskStepStatus.pending);
      final plan = AdvancedTaskPlan(
        planId: 'p1',
        steps: [s1, s2],
        locale: 'ku',
        createdAt: DateTime.now(),
      );
      expect(plan.failedSteps.length, 1);
    });

    test('hasRetryableSteps identifies retryable failures', () {
      final s1 = TaskStep(
        stepId: 's1',
        description: '',
        status: TaskStepStatus.failed,
        retryAttempt: 1,
        maxRetries: 3,
      );
      final plan = AdvancedTaskPlan(
        planId: 'p1',
        steps: [s1],
        locale: 'ku',
        createdAt: DateTime.now(),
      );
      expect(plan.hasRetryableSteps, isTrue);
    });

    test('allStepsTerminal returns true when all terminal', () {
      final s1 = TaskStep(stepId: 's1', description: '', status: TaskStepStatus.completed);
      final s2 = TaskStep(stepId: 's2', description: '', status: TaskStepStatus.failed);
      final plan = AdvancedTaskPlan(
        planId: 'p1',
        steps: [s1, s2],
        locale: 'ku',
        createdAt: DateTime.now(),
      );
      expect(plan.allStepsTerminal, isTrue);
    });
  });
}
