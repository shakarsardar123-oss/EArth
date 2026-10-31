/// goal_tracker_service.dart
/// AURA Assistant – Step 25: Capability 3 — Goal Tracking
///
/// Abstract service interface for tracking goal progress.
library;

import '../models/agent_goal.dart';
import '../models/goal_progress.dart';

/// Service responsible for tracking and managing goals throughout
/// task execution.
abstract class GoalTrackerService {
  /// Register a new goal for tracking.
  AgentGoal registerGoal({
    required String planId,
    required String description,
    required String locale,
  });

  /// Update goal progress.
  GoalProgress updateGoalProgress({
    required String goalId,
    required double progress,
  });

  /// Mark a goal as achieved.
  AgentGoal markGoalAchieved(String goalId);

  /// Mark a goal as failed.
  AgentGoal markGoalFailed(String goalId, String reason);

  /// Get all goals for a plan.
  List<AgentGoal> goalsForPlan(String planId);

  /// Get overall goal completion percentage for a plan.
  double planGoalCompletion(String planId);
}
