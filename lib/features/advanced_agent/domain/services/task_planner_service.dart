/// task_planner_service.dart
/// AURA Assistant – Step 25: Capability 1 — Multi-Step Task Planning
///
/// Abstract service interface for creating multi-step execution plans.
library;

import '../models/advanced_task_plan.dart';
import '../models/agent_goal.dart';

/// Service responsible for creating structured multi-step task plans
/// from user requests and goals.
abstract class TaskPlannerService {
  /// Create a plan from a user request and optional goals.
  /// Returns null if planning fails (fail-closed: no partial plans).
  Future<AdvancedTaskPlan?> createPlan({
    required String userRequest,
    required String locale,
    List<AgentGoal> goals = const [],
  });

  /// Validate that a plan is internally consistent
  /// (all dependencies resolve, no cycles, etc.).
  bool validatePlan(AdvancedTaskPlan plan);

  /// Estimate the number of steps a plan will require
  /// (used for progress tracking initialization).
  int estimateStepCount(String userRequest, String locale);
}
