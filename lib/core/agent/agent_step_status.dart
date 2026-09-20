/// Status of a single agent step in its lifecycle.
enum AgentStepStatus {
  /// Step has not started yet.
  pending,

  /// Step is currently executing.
  running,

  /// Step completed successfully.
  succeeded,

  /// Step failed.
  failed,

  /// Step was skipped (e.g., dependency failed).
  skipped,

  /// Step was cancelled.
  cancelled;

  bool get isDone =>
      this == AgentStepStatus.succeeded ||
      this == AgentStepStatus.failed ||
      this == AgentStepStatus.skipped ||
      this == AgentStepStatus.cancelled;
}
