/// task_progress_ui_state.dart
/// AURA Assistant – Step 25: Advanced Agent Capabilities
///
/// UI state model for the task progress presentation layer.
/// This is the bridge between the domain [TaskProgressState]
/// and the UI widgets. Locale defaults to Kurdish Sorani ('ku').
library;

import '../domain/models/task_progress_state.dart';
import '../domain/models/pause_resume_state.dart';
import '../domain/models/advanced_task_plan.dart';

/// Visual status of the task progress in the UI.
enum TaskProgressUIStatus {
  /// Task is idle, waiting to start.
  idle,

  /// Task is actively running.
  running,

  /// Task has been paused by the user.
  paused,

  /// Task completed successfully.
  completed,

  /// Task failed (may be recoverable).
  failed,

  /// Task was cancelled by the user.
  cancelled,

  /// Task is running in offline/degraded mode.
  degraded,

  /// Task was denied by safety gate.
  denied,

  /// Unknown state — FAIL-CLOSED → treated as denied.
  unknown,
  ;

  /// FAIL-CLOSED: any unknown name maps to [unknown].
  static TaskProgressUIStatus fromName(String name) {
    return TaskProgressUIStatus.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TaskProgressUIStatus.unknown,
    );
  }

  /// Whether this status represents a terminal state.
  bool get isTerminal =>
      this == TaskProgressUIStatus.completed ||
      this == TaskProgressUIStatus.failed ||
      this == TaskProgressUIStatus.cancelled ||
      this == TaskProgressUIStatus.denied ||
      this == TaskProgressUIStatus.unknown;
}

/// UI-friendly representation of a task step for display.
class UIStepItem {
  final String stepId;
  final String description;
  final String statusLabel;
  final bool isActive;
  final bool isCompleted;
  final bool isFailed;
  final double stepProgress;
  final String? errorMessage;
  final String? toolId;
  final int retryAttempt;
  final int maxRetries;

  const UIStepItem({
    required this.stepId,
    required this.description,
    this.statusLabel = '',
    this.isActive = false,
    this.isCompleted = false,
    this.isFailed = false,
    this.stepProgress = 0.0,
    this.errorMessage,
    this.toolId,
    this.retryAttempt = 0,
    this.maxRetries = 3,
  });

  /// Whether the step can be retried in the UI.
  bool get canRetry => isFailed && retryAttempt < maxRetries;

  @override
  String toString() =>
      'UIStepItem(id: $stepId, status: $statusLabel, progress: $stepProgress)';
}

/// UI-friendly representation of a goal for display.
class UIGoalItem {
  final String goalId;
  final String description;
  final String statusLabel;
  final double progress;
  final bool isAchieved;

  const UIGoalItem({
    required this.goalId,
    required this.description,
    this.statusLabel = '',
    this.progress = 0.0,
    this.isAchieved = false,
  });

  @override
  String toString() =>
      'UIGoalItem(id: $goalId, achieved: $isAchieved, progress: $progress)';
}

/// Comprehensive UI state for the task progress screen.
/// FAIL-CLOSED: unknown → denied, error → failed.
class TaskProgressUIState {
  final String planId;
  final TaskProgressUIStatus status;
  final double progress;
  final int totalSteps;
  final int completedSteps;
  final int failedSteps;
  final int inProgressSteps;
  final int pausedSteps;
  final String? currentStepId;
  final String? currentStepDescription;
  final List<UIStepItem> steps;
  final List<UIGoalItem> goals;
  final bool canPause;
  final bool canResume;
  final bool canCancel;
  final bool isPaused;
  final bool isCancelled;
  final String? lastErrorMessage;
  final String? executionLog;
  final Duration? executionDuration;
  final String locale;
  final DateTime updatedAt;

  const TaskProgressUIState({
    required this.planId,
    this.status = TaskProgressUIStatus.idle,
    this.progress = 0.0,
    this.totalSteps = 0,
    this.completedSteps = 0,
    this.failedSteps = 0,
    this.inProgressSteps = 0,
    this.pausedSteps = 0,
    this.currentStepId,
    this.currentStepDescription,
    this.steps = const [],
    this.goals = const [],
    this.canPause = false,
    this.canResume = false,
    this.canCancel = false,
    this.isPaused = false,
    this.isCancelled = false,
    this.lastErrorMessage,
    this.executionLog,
    this.executionDuration,
    this.locale = 'ku',
    required this.updatedAt,
  });

  /// Percentage representation (0-100).
  int get percentage => (progress * 100).round().clamp(0, 100);

  /// Whether the task is in a terminal state.
  bool get isTerminal => status.isTerminal;

  /// Whether the task has any failed steps.
  bool get hasFailures => failedSteps > 0;

  /// Whether the task is in degraded mode.
  bool get isDegraded => status == TaskProgressUIStatus.degraded;

  /// FAIL-CLOSED: factory from domain [TaskProgressState].
  /// Maps domain state to UI state, applying FAIL-CLOSED defaults.
  factory TaskProgressUIState.fromDomainState(
    TaskProgressState domainState, {
    List<UIStepItem> steps = const [],
    List<UIGoalItem> goals = const [],
    String? executionLog,
    Duration? executionDuration,
    String locale = 'ku',
  }) {
    final uiStatus = _mapPlanStatusToUI(domainState.planStatus, domainState.pauseResumeState);

    return TaskProgressUIState(
      planId: domainState.planId,
      status: uiStatus,
      progress: domainState.planProgress,
      totalSteps: domainState.totalSteps,
      completedSteps: domainState.completedSteps,
      failedSteps: domainState.failedSteps,
      inProgressSteps: domainState.inProgressSteps,
      pausedSteps: domainState.pausedSteps,
      currentStepId: domainState.currentStepId,
      steps: steps,
      goals: goals,
      canPause: domainState.pauseResumeState == PauseResumeState.running ||
          domainState.pauseResumeState == PauseResumeState.resuming,
      canResume: domainState.pauseResumeState == PauseResumeState.paused ||
          domainState.pauseResumeState == PauseResumeState.pausing,
      canCancel: domainState.planStatus != PlanStatus.cancelled,
      isPaused: domainState.isPaused,
      isCancelled: domainState.isCancelled,
      lastErrorMessage: domainState.lastErrorMessage,
      executionLog: executionLog,
      executionDuration: executionDuration,
      locale: locale,
      updatedAt: domainState.updatedAt,
    );
  }

  /// FAIL-CLOSED: factory for error UI state.
  factory TaskProgressUIState.failed({
    required String planId,
    required String errorMessage,
    String locale = 'ku',
  }) =>
      TaskProgressUIState(
        planId: planId,
        status: TaskProgressUIStatus.failed,
        lastErrorMessage: errorMessage,
        locale: locale,
        updatedAt: DateTime.now(),
      );

  /// FAIL-CLOSED: factory for denied UI state.
  factory TaskProgressUIState.denied({
    required String planId,
    String? reason,
    String locale = 'ku',
  }) =>
      TaskProgressUIState(
        planId: planId,
        status: TaskProgressUIStatus.denied,
        lastErrorMessage: reason ?? 'Action denied by safety gate (fail-closed).',
        locale: locale,
        updatedAt: DateTime.now(),
      );

  /// FAIL-CLOSED: unknown → denied.
  factory TaskProgressUIState.unknown({
    required String planId,
    String locale = 'ku',
  }) =>
      TaskProgressUIState.denied(
        planId: planId,
        reason: 'Unknown state — failing closed (denied).',
        locale: locale,
      );

  TaskProgressUIState copyWith({
    String? planId,
    TaskProgressUIStatus? status,
    double? progress,
    int? totalSteps,
    int? completedSteps,
    int? failedSteps,
    int? inProgressSteps,
    int? pausedSteps,
    String? currentStepId,
    String? currentStepDescription,
    List<UIStepItem>? steps,
    List<UIGoalItem>? goals,
    bool? canPause,
    bool? canResume,
    bool? canCancel,
    bool? isPaused,
    bool? isCancelled,
    String? lastErrorMessage,
    String? executionLog,
    Duration? executionDuration,
    String? locale,
    DateTime? updatedAt,
  }) =>
      TaskProgressUIState(
        planId: planId ?? this.planId,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        totalSteps: totalSteps ?? this.totalSteps,
        completedSteps: completedSteps ?? this.completedSteps,
        failedSteps: failedSteps ?? this.failedSteps,
        inProgressSteps: inProgressSteps ?? this.inProgressSteps,
        pausedSteps: pausedSteps ?? this.pausedSteps,
        currentStepId: currentStepId ?? this.currentStepId,
        currentStepDescription: currentStepDescription ?? this.currentStepDescription,
        steps: steps ?? this.steps,
        goals: goals ?? this.goals,
        canPause: canPause ?? this.canPause,
        canResume: canResume ?? this.canResume,
        canCancel: canCancel ?? this.canCancel,
        isPaused: isPaused ?? this.isPaused,
        isCancelled: isCancelled ?? this.isCancelled,
        lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
        executionLog: executionLog ?? this.executionLog,
        executionDuration: executionDuration ?? this.executionDuration,
        locale: locale ?? this.locale,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Map domain PlanStatus + PauseResumeState to UI status.
  /// FAIL-CLOSED: unknown → denied.
  static TaskProgressUIStatus _mapPlanStatusToUI(
    PlanStatus planStatus,
    PauseResumeState pauseResumeState,
  ) {
    if (pauseResumeState == PauseResumeState.paused ||
        pauseResumeState == PauseResumeState.pausing) {
      return TaskProgressUIStatus.paused;
    }
    switch (planStatus) {
      case PlanStatus.draft:
        return TaskProgressUIStatus.idle;
      case PlanStatus.active:
        return TaskProgressUIStatus.running;
      case PlanStatus.completed:
        return TaskProgressUIStatus.completed;
      case PlanStatus.failed:
        return TaskProgressUIStatus.failed;
      case PlanStatus.cancelled:
        return TaskProgressUIStatus.cancelled;
      case PlanStatus.paused:
        return TaskProgressUIStatus.paused;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskProgressUIState &&
          planId == other.planId &&
          status == other.status &&
          progress == other.progress;

  @override
  int get hashCode => Object.hash(planId, status, progress);

  @override
  String toString() =>
      'TaskProgressUIState(plan: $planId, status: $status, '
      'progress: $percentage%, steps: $completedSteps/$totalSteps)';
}
