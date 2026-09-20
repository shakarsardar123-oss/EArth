/// goal_progress_test.dart
/// Structural tests for GoalProgress model.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/goal_progress.dart';

void main() {
  group('GoalProgress', () {
    test('stores progress value between 0.0 and 1.0', () {
      final gp = GoalProgress(
        progressId: 'gp1',
        goalId: 'g1',
        progressValue: 0.75,
      );
      expect(gp.progressValue, 0.75);
      expect(gp.goalId, 'g1');
      expect(gp.progressId, 'gp1');
    });

    test('zero progress', () {
      final gp = GoalProgress(
        progressId: 'gp2',
        goalId: 'g2',
        progressValue: 0.0,
      );
      expect(gp.progressValue, 0.0);
    });

    test('full progress', () {
      final gp = GoalProgress(
        progressId: 'gp3',
        goalId: 'g3',
        progressValue: 1.0,
      );
      expect(gp.progressValue, 1.0);
    });
  });
}
