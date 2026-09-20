/// Step 23 — Orchestration State
/// Immutable state model representing the full lifecycle of a user request.
///
/// FAIL-CLOSED: Any unrecognized or error state defaults to [failed].
/// UNKNOWN = DENY, ERROR = DENY, UNAVAILABLE = DENY.

/// The canonical phases a request moves through from reception to completion.
///
/// Reuses existing Step 22 ToolExecutionPhase semantics where overlapping.
/// New phases cover orchestration-specific concerns (understanding, planning,
/// memory lookup, security/permission/confirmation checking, responding).
enum OrchestrationPhase {
  idle,
  understanding,
  planning,
  memoryLookup,
  toolDiscovery,
  securityChecking,
  permissionChecking,
  awaitingConfirmation,
  executing,
  verifying,
  recovering,
  responding,
  completed,
  failed,
  cancelled,
  ;

  /// Whether this phase represents a terminal (no further transitions).
  bool get isTerminal =>
      this == OrchestrationPhase.completed ||
      this == OrchestrationPhase.failed ||
      this == OrchestrationPhase.cancelled;

  /// Whether the orchestrator may transition *away* from this phase.
  bool get isTransitionable => !isTerminal;

  /// FAIL-CLOSED: any unknown/unrecognized phase is treated as [failed].
  static OrchestrationPhase fromName(String name) {
    return OrchestrationPhase.values.firstWhere(
      (e) => e.name == name,
      orElse: () => OrchestrationPhase.failed,
    );
  }
}

/// Immutable snapshot of the orchestration state for a single request.
///
/// Every field is final; transitions return a *new* instance via [copyWith].
class OrchestrationState {
  final String requestId;
  final OrchestrationPhase phase;
  final DateTime timestamp;
  final String? errorMessage;
  final int retryAttempt;

  const OrchestrationState({
    required this.requestId,
    required this.phase,
    required this.timestamp,
    this.errorMessage,
    this.retryAttempt = 0,
  });

  /// Initial state for a new request.
  factory OrchestrationState.initial(String requestId) => OrchestrationState(
        requestId: requestId,
        phase: OrchestrationPhase.idle,
        timestamp: DateTime.now(),
      );

  /// FAIL-CLOSED error state.
  factory OrchestrationState.failed({
    required String requestId,
    required String errorMessage,
    int retryAttempt = 0,
  }) =>
      OrchestrationState(
        requestId: requestId,
        phase: OrchestrationPhase.failed,
        timestamp: DateTime.now(),
        errorMessage: errorMessage,
        retryAttempt: retryAttempt,
      );

  /// Cancelled state.
  factory OrchestrationState.cancelled(String requestId) => OrchestrationState(
        requestId: requestId,
        phase: OrchestrationPhase.cancelled,
        timestamp: DateTime.now(),
      );

  OrchestrationState copyWith({
    OrchestrationPhase? phase,
    String? errorMessage,
    int? retryAttempt,
  }) =>
      OrchestrationState(
        requestId: requestId,
        phase: phase ?? this.phase,
        timestamp: DateTime.now(),
        errorMessage: errorMessage ?? this.errorMessage,
        retryAttempt: retryAttempt ?? this.retryAttempt,
      );

  @override
  String toString() =>
      'OrchestrationState(requestId: $requestId, phase: $phase, '
      'retryAttempt: $retryAttempt, error: $errorMessage)';
}
