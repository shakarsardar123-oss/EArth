/// recovery_state.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Immutable recovery state with RecoveryPhase enum (11 phases),
/// copyWith with clear* boolean flags, convenience getters,
/// and custom ==/hashCode.
///
/// Follows the MemoryState pattern from Step 17.
///
/// Kurdish-first, local-first, privacy-conscious.
library;

import 'package:meta/meta.dart';
import 'agent_plan.dart';
import 'recovery_context.dart';
import 'recovery_failure.dart';
import 'recovery_phase.dart';
import 'retry_policy.dart';

/// Immutable state for the agent recovery feature.
///
/// Tracks the current phase of recovery, the active context,
/// retry policy, and progress indicators.
@immutable
class RecoveryState {
  /// Current phase in the recovery lifecycle.
  final RecoveryPhase phase;

  /// The recovery context (null when idle).
  final RecoveryContext? context;

  /// The retry policy governing current recovery behavior.
  final RetryPolicy retryPolicy;

  /// The original agent plan (before any replanning).
  final AgentPlan? originalPlan;

  /// The current (possibly replanned) agent plan.
  final AgentPlan? currentPlan;

  /// The last failure that triggered recovery.
  final RecoveryFailure? lastFailure;

  /// Number of steps that completed successfully.
  final int completedStepCount;

  /// Number of steps remaining.
  final int remainingStepCount;

  /// Timestamp of the last state change (ms since epoch).
  final int lastUpdatedTimestamp;

  const RecoveryState({
    this.phase = RecoveryPhase.idle,
    this.context,
    this.retryPolicy = const RetryPolicy(),
    this.originalPlan,
    this.currentPlan,
    this.lastFailure,
    this.completedStepCount = 0,
    this.remainingStepCount = 0,
    this.lastUpdatedTimestamp = 0,
  });

  // ─── Convenience getters ──────────────────────────────────────────

  /// Whether recovery is currently idle (no active recovery).
  bool get isIdle => phase == RecoveryPhase.idle;

  /// Whether an agent step is currently executing.
  bool get isExecuting => phase == RecoveryPhase.executing;

  /// Whether post-action verification is in progress.
  bool get isVerifying => phase == RecoveryPhase.verifying;

  /// Whether a failure has been detected.
  bool get isFailed => phase == RecoveryPhase.failed;

  /// Whether failure analysis is in progress.
  bool get isAnalyzingFailure => phase == RecoveryPhase.analyzingFailure;

  /// Whether a recovery strategy is being applied.
  bool get isRecovering => phase == RecoveryPhase.recovering;

  /// Whether the plan is being replanned.
  bool get isReplanning => phase == RecoveryPhase.replanning;

  /// Whether a step is being retried.
  bool get isRetrying => phase == RecoveryPhase.retrying;

  /// Whether recovery completed successfully.
  bool get isSucceeded => phase == RecoveryPhase.succeeded;

  /// Whether recovery was aborted.
  bool get isAborted => phase == RecoveryPhase.aborted;

  /// Whether recovery was cancelled by user.
  bool get isCancelled => phase == RecoveryPhase.cancelled;

  /// Whether any active recovery operation is in progress.
  bool get isActive =>
      !isIdle && !isSucceeded && !isAborted && !isCancelled;

  /// Whether a terminal state has been reached.
  bool get isTerminal =>
      isSucceeded || isAborted || isCancelled;

  /// Whether retries have been exhausted.
  bool get hasRetriesExhausted =>
      retryPolicy.hasStepRetriesExhausted ||
      retryPolicy.hasTotalRetriesExhausted;

  /// Whether cancellation has been requested.
  bool get isCancellationRequested => retryPolicy.isCancelled;

  // ─── copyWith ────────────────────────────────────────────────────

  RecoveryState copyWith({
    RecoveryPhase? phase,
    RecoveryContext? context,
    bool clearContext = false,
    RetryPolicy? retryPolicy,
    AgentPlan? originalPlan,
    bool clearOriginalPlan = false,
    AgentPlan? currentPlan,
    bool clearCurrentPlan = false,
    RecoveryFailure? lastFailure,
    bool clearLastFailure = false,
    int? completedStepCount,
    int? remainingStepCount,
    int? lastUpdatedTimestamp,
  }) =>
      RecoveryState(
        phase: phase ?? this.phase,
        context: clearContext ? null : (context ?? this.context),
        retryPolicy: retryPolicy ?? this.retryPolicy,
        originalPlan:
            clearOriginalPlan ? null : (originalPlan ?? this.originalPlan),
        currentPlan:
            clearCurrentPlan ? null : (currentPlan ?? this.currentPlan),
        lastFailure:
            clearLastFailure ? null : (lastFailure ?? this.lastFailure),
        completedStepCount:
            completedStepCount ?? this.completedStepCount,
        remainingStepCount:
            remainingStepCount ?? this.remainingStepCount,
        lastUpdatedTimestamp:
            lastUpdatedTimestamp ?? this.lastUpdatedTimestamp,
      );

  // ─── Equality ────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecoveryState &&
          phase == other.phase &&
          retryPolicy == other.retryPolicy &&
          completedStepCount == other.completedStepCount &&
          remainingStepCount == other.remainingStepCount;

  @override
  int get hashCode => Object.hash(
        phase,
        retryPolicy,
        completedStepCount,
        remainingStepCount,
      );

  @override
  String toString() =>
      'RecoveryState(phase: $phase, completed: $completedStepCount, '
      'remaining: $remainingStepCount)';
}
