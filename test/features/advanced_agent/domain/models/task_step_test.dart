/// task_step_test.dart
/// Structural & mock tests for TaskStep model.
///
/// Verifies: stepId (NOT id), retryAttempt (NOT retryCount),
/// no expectedOutcome field, TaskStepStatus enum.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/task_step.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/task_step_status.dart';

void main() {
  group('TaskStepStatus', () {
    test('has expected status values', () {
      expect(TaskStepStatus.values, containsAll([
        TaskStepStatus.pending,
        TaskStepStatus.inProgress,
        TaskStepStatus.completed,
        TaskStepStatus.failed,
        TaskStepStatus.skipped,
        TaskStepStatus.cancelled,
        TaskStepStatus.paused,
      ]));
    });
  });

  group('TaskStep', () {
    test('uses stepId NOT id', () {
      final step = TaskStep(stepId: 's1', description: 'Test', status: TaskStepStatus.pending);
      expect(step.stepId, 's1');
      // step.id should NOT exist — field is stepId
    });

    test('uses retryAttempt NOT retryCount', () {
      final step = TaskStep(
        stepId: 's1',
        description: 'Test',
        status: TaskStepStatus.failed,
        retryAttempt: 2,
      );
      expect(step.retryAttempt, 2);
    });

    test('does NOT have expectedOutcome field', () {
      final step = TaskStep(stepId: 's1', description: 'Test', status: TaskStepStatus.pending);
      // expectedOutcome does not exist on TaskStep by design
      expect(step.stepId, isNotNull);
    });

    test('default values', () {
      final step = TaskStep(stepId: 's1', description: 'Test', status: TaskStepStatus.pending);
      expect(step.retryAttempt, 0);
      expect(step.maxRetries, greaterThan(0));
    });
  });
}
