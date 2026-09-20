/// Step 24 — Trigger State
///
/// Immutable state representing the lifecycle of a trigger request.
/// FAIL-CLOSED: any unrecognized or error state → [denied] or [failed].
/// UNKNOWN = DENY, ERROR = DENY, UNAVAILABLE = DENY.

enum TriggerPhase {
  idle,
  received,
  validating,
  authorized,
  launching,
  launched,
  denied,
  failed,
  unavailable,
  ;

  /// Whether this phase is terminal (no further transitions).
  bool get isTerminal =>
      this == TriggerPhase.denied ||
      this == TriggerPhase.failed ||
      this == TriggerPhase.unavailable ||
      this == TriggerPhase.launched;

  /// FAIL-CLOSED: unrecognized names → [failed].
  static TriggerPhase fromName(String name) {
    return TriggerPhase.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TriggerPhase.failed,
    );
  }
}

/// Immutable trigger state for a single trigger request.
class TriggerState {
  final String triggerId;
  final TriggerPhase phase;
  final DateTime timestamp;
  final String? errorMessage;
  final String? denialReason;

  const TriggerState({
    required this.triggerId,
    required this.phase,
    required this.timestamp,
    this.errorMessage,
    this.denialReason,
  });

  /// Initial state for a new trigger request.
  factory TriggerState.initial(String triggerId) => TriggerState(
        triggerId: triggerId,
        phase: TriggerPhase.idle,
        timestamp: DateTime.now(),
      );

  /// FAIL-CLOSED: denied state with reason.
  factory TriggerState.denied({
    required String triggerId,
    required String denialReason,
  }) =>
      TriggerState(
        triggerId: triggerId,
        phase: TriggerPhase.denied,
        timestamp: DateTime.now(),
        denialReason: denialReason,
      );

  /// FAIL-CLOSED: failed state with error message.
  factory TriggerState.failed({
    required String triggerId,
    required String errorMessage,
  }) =>
      TriggerState(
        triggerId: triggerId,
        phase: TriggerPhase.failed,
        timestamp: DateTime.now(),
        errorMessage: errorMessage,
      );

  /// Unavailable state (e.g., Flutter engine not running).
  factory TriggerState.unavailable({
    required String triggerId,
    required String errorMessage,
  }) =>
      TriggerState(
        triggerId: triggerId,
        phase: TriggerPhase.unavailable,
        timestamp: DateTime.now(),
        errorMessage: errorMessage,
      );

  /// Launched state (trigger successfully forwarded to AURA pipeline).
  factory TriggerState.launched(String triggerId) => TriggerState(
        triggerId: triggerId,
        phase: TriggerPhase.launched,
        timestamp: DateTime.now(),
      );

  /// Immutable copy.
  TriggerState copyWith({
    TriggerPhase? phase,
    String? errorMessage,
    String? denialReason,
  }) =>
      TriggerState(
        triggerId: triggerId,
        phase: phase ?? this.phase,
        timestamp: DateTime.now(),
        errorMessage: errorMessage ?? this.errorMessage,
        denialReason: denialReason ?? this.denialReason,
      );

  @override
  String toString() =>
      'TriggerState(triggerId: $triggerId, phase: $phase, '
      'error: $errorMessage, denial: $denialReason)';
}
