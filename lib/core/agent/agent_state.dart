/// State machine for the Agent Engine.
///
/// Phase 4 lifecycle: understand → plan → validate → execute →
///   observe → verify → replan/retry → complete
///
/// Original Phase 1–3 states are preserved for backward compatibility.
enum AgentState {
  // ── Original states (Phase 1–3) — DO NOT REMOVE ──
  idle,
  planning,
  executing,
  responding,
  error,

  // ── Phase 4 lifecycle states ──
  /// Agent is analyzing user input to determine intent.
  understanding,

  /// Agent is validating the plan / tool calls before execution.
  validating,

  /// Agent is observing the result of a tool execution.
  observing,

  /// Agent is verifying that a tool result meets expectations.
  verifying,

  /// Agent is re-planning after a failure or unexpected result.
  replanning,

  /// Agent is paused waiting for user confirmation.
  waitingForConfirmation,

  /// Agent has successfully completed the entire task.
  completed,

  /// Agent has failed and cannot recover.
  failed,

  /// Agent execution was cancelled by the user.
  cancelled;

  /// Whether the agent is actively doing work (not idle/completed/failed/cancelled).
  bool get isActive =>
      this != AgentState.idle &&
      this != AgentState.completed &&
      this != AgentState.failed &&
      this != AgentState.cancelled;

  /// Whether the agent is in a terminal state.
  bool get isTerminal =>
      this == AgentState.completed ||
      this == AgentState.failed ||
      this == AgentState.cancelled ||
      this == AgentState.idle;

  /// Whether the agent is in an error-like state (backward compat).
  bool get isError => this == AgentState.error || this == AgentState.failed;
}
