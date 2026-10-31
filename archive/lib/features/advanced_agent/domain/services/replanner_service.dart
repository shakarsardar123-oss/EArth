/// replanner_service.dart
/// AURA Assistant – Step 25: Capability 2 — Dynamic Replanning
///
/// Abstract service interface for adapting plans when conditions change.
library;

import '../models/advanced_task_plan.dart';
import '../models/advanced_agent_failure.dart';

/// Service responsible for dynamically adapting an existing plan
/// when steps fail, conditions change, or new information arrives.
abstract class ReplannerService {
  /// Attempt to replan based on a failure encountered during execution.
  /// Returns a new plan, or null if replanning fails (fail-closed).
  Future<AdvancedTaskPlan?> replanOnFailure({
    required AdvancedTaskPlan currentPlan,
    required AdvancedAgentFailure failure,
    required String locale,
  });

  /// Attempt to replan when a goal is added or changed.
  /// Returns a new plan, or null if replanning fails (fail-closed).
  Future<AdvancedTaskPlan?> replanOnGoalChange({
    required AdvancedTaskPlan currentPlan,
    required String reason,
    required String locale,
  });

  /// Check whether a plan needs replanning.
  bool needsReplanning(AdvancedTaskPlan plan);

  /// Maximum number of replan attempts before abort.
  int get maxReplanAttempts;
}
