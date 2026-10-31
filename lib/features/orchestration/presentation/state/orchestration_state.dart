/// Step 23 — Orchestration UI State
///
/// Presentation-layer state model for the orchestration feature.
/// Bridges domain state to UI widgets.
///
/// FAIL-CLOSED: unknown phases → failed; offline → degraded.
/// OrchestrationState has NO locale field — locale is on UnifiedRequestContext.
/// OrchestrationPhase has NO offlineDegraded — use isOffline flag on context.

import '../../domain/orchestration_domain.dart';

class OrchestrationUiState {
  final OrchestrationPhase phase;
  final String requestId;
  final int retryAttempt;
  final String? errorMessage;
  final OrchestrationResult? result;
  final bool isOffline;

  const OrchestrationUiState({
    required this.phase,
    required this.requestId,
    this.retryAttempt = 0,
    this.errorMessage,
    this.result,
    this.isOffline = false,
  });

  /// Create initial UI state.
  factory OrchestrationUiState.initial() => const OrchestrationUiState(
    phase: OrchestrationPhase.idle,
    requestId: '',
  );

  /// Whether the orchestration is in an active (non-terminal) phase.
  bool get isActive =>
      phase != OrchestrationPhase.idle &&
      phase != OrchestrationPhase.completed &&
      phase != OrchestrationPhase.failed &&
      phase != OrchestrationPhase.cancelled;

  /// Whether orchestration reached a terminal phase.
  bool get isTerminal =>
      phase == OrchestrationPhase.completed ||
      phase == OrchestrationPhase.failed ||
      phase == OrchestrationPhase.cancelled;

  /// Whether the result was successful.
  /// Uses result.succeeded (not isSuccess).
  bool get isSuccessful => result != null && result!.succeeded;

  /// Whether the result was denied.
  /// Uses result.wasDenied (not isFailed).
  bool get isDenied => result != null && result!.wasDenied;

  /// Whether the result was cancelled.
  /// Uses result.wasCancelled (not isCancelled).
  bool get isUserCancelled => result != null && result!.wasCancelled;

  /// Whether orchestration failed (not denied, not cancelled).
  bool get isFailedResult => result != null && !result!.succeeded && !result!.wasDenied && !result!.wasCancelled;

  /// Whether operating in offline/degraded mode.
  /// Derived from isOffline flag (not from OrchestrationPhase).
  bool get isOfflineDegraded => isOffline && phase != OrchestrationPhase.idle;

  /// Get the localized user-facing message from the result.
  /// Uses result.localizedResponse (not userMessage/locale).
  String? get localizedMessage => result?.localizedResponse;

  /// Copy with updated fields.
  OrchestrationUiState copyWith({
    OrchestrationPhase? phase,
    String? requestId,
    int? retryAttempt,
    String? errorMessage,
    OrchestrationResult? result,
    bool? isOffline,
  }) =>
      OrchestrationUiState(
        phase: phase ?? this.phase,
        requestId: requestId ?? this.requestId,
        retryAttempt: retryAttempt ?? this.retryAttempt,
        errorMessage: errorMessage ?? this.errorMessage,
        result: result ?? this.result,
        isOffline: isOffline ?? this.isOffline,
      );

  /// Create from domain context — maps domain fields to presentation.
  factory OrchestrationUiState.fromContext(UnifiedRequestContext ctx) =>
      OrchestrationUiState(
        phase: ctx.state.phase,
        requestId: ctx.requestId,
        retryAttempt: ctx.state.retryAttempt,
        errorMessage: ctx.state.errorMessage,
        isOffline: ctx.isOffline,
      );

  /// Create with a result — convenience for terminal states.
  factory OrchestrationUiState.withResult(OrchestrationResult result, {bool isOffline = false}) =>
      OrchestrationUiState(
        phase: result.succeeded
            ? OrchestrationPhase.completed
            : result.wasDenied
                ? OrchestrationPhase.failed
                : result.wasCancelled
                    ? OrchestrationPhase.cancelled
                    : OrchestrationPhase.failed,
        requestId: result.requestId,
        result: result,
        isOffline: isOffline,
      );

  @override
  String toString() =>
      'OrchestrationUiState(phase: $phase, requestId: $requestId, '
      'retry: $retryAttempt, offline: $isOffline, '
      'result: ${result != null ? "present" : "none"})';
}
