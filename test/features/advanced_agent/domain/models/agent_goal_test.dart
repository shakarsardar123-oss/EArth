/// agent_goal_test.dart
/// Structural tests for AgentGoal model.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/agent_goal.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/goal_status.dart';

void main() {
  group('AgentGoal', () {
    test('constructs with required fields', () {
      final goal = AgentGoal(
        goalId: 'g1',
        description: 'Translate text to Kurdish Sorani',
        status: GoalStatus.pending,
      );
      expect(goal.goalId, 'g1');
      expect(goal.description, 'Translate text to Kurdish Sorani');
      expect(goal.status, GoalStatus.pending);
    });

    test('goalId and description are non-empty', () {
      final goal = AgentGoal(
        goalId: 'g2',
        description: 'Another goal',
        status: GoalStatus.inProgress,
      );
      expect(goal.goalId, isNotEmpty);
      expect(goal.description, isNotEmpty);
    });
  });
}
