/// task_progress_state.dart
/// AURA Assistant – Step 25: Advanced Agent Capabilities
///
/// Overall task progress state (capability 8: Task Progress State).
/// Tracks the combined state of all plan steps and goals.
library;

import 'advanced_task_plan.dart';
import 'agent_goal.dart';
import 'pause_resume_state.dart';

/// Overall progress state for an advanced agent task execution.
class TaskProgressState {
  final String planId;
  final PlanStatus planStatus;
  final double planProgress;
  final int totalSteps;
  final int completedSteps;
  final int failedSteps;
  final int inProgressSteps;
  final int pausedSteps;
  final String? currentStepId;
  final List<AgentGoal> goals;
  final PauseResumeState pauseResumeState;
  final String? lastErrorMessage;
  final DateTime updatedAt;

  const TaskProgressState({
    required this.planId,
    this.planStatus = PlanStatus.draft,
    this.planProgress = 0.0,
    this.totalSteps = 0,
    this.completedSteps = 0,
    this.failedSteps = 0,
    this.inProgressSteps = 0,
    this.pausedSteps = 0,
    this.currentStepId,
    this.goals = const [],
    this.pauseResumeState = PauseResumeState.running,
    this.lastErrorMessage,
    required this.updatedAt,
  });

  /// Whether the plan is fully complete.
  bool get isComplete => planStatus == PlanStatus.completed;

  /// Whether the plan has failed.
  bool get isFailed => planStatus == PlanStatus.failed;

  /// Whether the plan is paused.
  bool get isPaused => pauseResumeState == PauseResumeState.paused;

  /// Whether the plan is cancelled.
  bool get isCancelled => planStatus == PlanStatus.cancelled;

  /// Percentage representation.
  int get percentage => (planProgress * 100).round().clamp(0, 100);

  /// Factory from an [AdvancedTaskPlan] and list of goals.
  factory TaskProgressState.fromPlan(
    AdvancedTaskPlan plan, {
    List<AgentGoal> goals = const [],
    PauseResumeState pauseResumeState = PauseResumeState.running,
    String? lastErrorMessage,
  }) =>
      TaskProgressState(
        planId: plan.planId,
        planStatus: plan.status,
        planProgress: plan.progress,
        totalSteps: plan.steps.length,
        completedSteps: plan.completedSteps,
        failedSteps: plan.failedSteps,
        inProgressSteps: plan.inProgressSteps,
        pausedSteps: plan.pausedSteps,
        currentStepId: plan.currentStep?.stepId,
        goals: goals,
        pauseResumeState: pauseResumeState,
        lastErrorMessage: lastErrorMessage,
        updatedAt: DateTime.now(),
      );

  /// FAIL-CLOSED: factory for error state.
  factory TaskProgressState.failed({
    required String planId,
    required String errorMessage,
  }) =>
      TaskProgressState(
        planId: planId,
        planStatus: PlanStatus.failed,
        lastErrorMessage: errorMessage,
        updatedAt: DateTime.now(),
      );

  TaskProgressState copyWith({
    String? planId,
    PlanStatus? planStatus,
    double? planProgress,
    int? totalSteps,
    int? completedSteps,
    int? failedSteps,
    int? inProgressSteps,
    int? pausedSteps,
    String? currentStepId,
    List<AgentGoal>? goals,
    PauseResumeState? pauseResumeState,
    String? lastErrorMessage,
    DateTime? updatedAt,
  }) =>
      TaskProgressState(
        planId: planId ?? this.planId,
        planStatus: planStatus ?? this.planStatus,
        planProgress: planProgress ?? this.planProgress,
        totalSteps: totalSteps ?? this.totalSteps,
        completedSteps: completedSteps ?? this.completedSteps,
        failedSteps: failedSteps ?? this.failedSteps,
        inProgressSteps: inProgressSteps ?? this.inProgressSteps,
        pausedSteps: pausedSteps ?? this.pausedSteps,
        currentStepId: currentStepId ?? this.currentStepId,
        goals: goals ?? this.goals,
        pauseResumeState: pauseResumeState ?? this.pauseResumeState,
        lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskProgressState &&
          planId == other.planId &&
          planStatus == other.planStatus &&
          planProgress == other.planProgress;

  @override
  int get hashCode =>
      Object.hash(planId, planStatus, planProgress);

  @override
  String toString() =>
      'TaskProgressState(plan: $planId, status: $planStatus, '
      'progress: $percentage%, steps: $completedSteps/$totalSteps)';
}
