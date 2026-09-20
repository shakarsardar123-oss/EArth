/// task_progress_state_test.dart
/// Structural tests for TaskProgressState model.
///
/// Verifies: .failed({planId, required errorMessage}) factory,
/// .buildProgress({...}) factory.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/task_progress_state.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/advanced_task_plan.dart';

void main() {
  group('TaskProgressState', () {
    test('.failed factory requires errorMessage', () {
      final state = TaskProgressState.failed(
        planId: 'plan1',
        errorMessage: 'Something went wrong',
      );
      expect(state.planId, 'plan1');
      expect(state.errorMessage, 'Something went wrong');
    });

    test('.buildProgress factory constructs progress', () {
      final state = TaskProgressState.buildProgress(
        planId: 'plan2',
        completedSteps: 5,
        totalSteps: 10,
      );
      expect(state.planId, 'plan2');
    });

    test('planId is always present', () {
      final state = TaskProgressState.failed(
        planId: 'p3',
        errorMessage: 'err',
      );
      expect(state.planId, isNotEmpty);
    });
  });
}
