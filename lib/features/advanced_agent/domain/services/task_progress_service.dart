/// task_progress_service.dart
/// AURA Assistant – Step 25: Capability 8 — Task Progress State
///
/// Abstract service interface for tracking overall task progress.
library;

import '../models/task_progress_state.dart';
import '../models/advanced_task_plan.dart';
import '../models/agent_goal.dart';
import '../models/pause_resume_state.dart';

/// Service responsible for tracking and reporting the overall
/// progress state of a task execution.
abstract class TaskProgressService {
  /// Get the current progress state for a plan.
  TaskProgressState getProgress(String planId);

  /// Build progress state from a plan and its goals.
  TaskProgressState buildProgress({
    required AdvancedTaskPlan plan,
    List<AgentGoal> goals = const [],
    PauseResumeState pauseResumeState = PauseResumeState.running,
    String? lastErrorMessage,
  });

  /// Stream of progress state updates for a plan.
  Stream<TaskProgressState> watchProgress(String planId);

  /// Record an error message for a plan.
  TaskProgressState recordError({
    required String planId,
    required String errorMessage,
  });

  /// Reset progress state for a plan (e.g., after replanning).
  TaskProgressState reset(String planId);
}
