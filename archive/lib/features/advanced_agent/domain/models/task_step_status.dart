/// task_step_status.dart
/// AURA Assistant – Step 25: Advanced Agent Capabilities
///
/// Status enum for individual task steps within a multi-step plan.
/// FAIL-CLOSED: unknown status is treated as [failed].
library;

/// The status of a single step in a [AdvancedTaskPlan].
///
/// FAIL-CLOSED: any unrecognized or error status defaults to [failed].
enum TaskStepStatus {
  /// Step has not yet started.
  pending,

  /// Step is currently executing.
  inProgress,

  /// Step completed successfully.
  completed,

  /// Step failed and may be recoverable.
  failed,

  /// Step was skipped (e.g., precondition not met, safe degrade).
  skipped,

  /// Step was cancelled by user or system.
  cancelled,

  /// Step is paused, waiting for resume.
  paused,
  ;

  /// Whether this status represents a terminal state.
  bool get isTerminal =>
      this == TaskStepStatus.completed ||
      this == TaskStepStatus.failed ||
      this == TaskStepStatus.cancelled ||
      this == TaskStepStatus.skipped;

  /// Whether the step is active (not terminal).
  bool get isActive => !isTerminal;

  /// Whether the step can be retried from this status.
  bool get canRetry =>
      this == TaskStepStatus.failed || this == TaskStepStatus.paused;

  /// FAIL-CLOSED: any unknown string maps to [failed].
  static TaskStepStatus fromName(String name) {
    return TaskStepStatus.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TaskStepStatus.failed,
    );
  }
}
