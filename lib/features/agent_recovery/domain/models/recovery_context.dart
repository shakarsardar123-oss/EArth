/// recovery_context.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Immutable recovery context that carries all the information
/// needed for the replanning engine to make decisions.
///
/// Kurdish-first, local-first, privacy-conscious.
library;

import 'package:meta/meta.dart';
import 'agent_plan.dart';
import 'recovery_failure.dart';
import 'recovery_strategy.dart';

/// A single previous recovery attempt.
@immutable
class RecoveryAttempt {
  /// The strategy that was attempted.
  final RecoveryStrategy strategy;

  /// Whether this attempt succeeded.
  final bool succeeded;

  /// The failure that occurred (if the attempt failed).
  final RecoveryFailure? failure;

  /// Timestamp of the attempt (milliseconds since epoch).
  final int timestamp;

  const RecoveryAttempt({
    required this.strategy,
    required this.succeeded,
    this.failure,
    required this.timestamp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecoveryAttempt &&
          strategy == other.strategy &&
          succeeded == other.succeeded &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(strategy, succeeded, timestamp);

  @override
  String toString() =>
      'RecoveryAttempt(strategy: $strategy, succeeded: $succeeded)';
}

/// Immutable context carrying all information for recovery decisions.
///
/// Includes the original request, current plan, failed step,
/// failure details, previous attempts, successful steps,
/// current screen state, chosen strategy, and retry count.
@immutable
class RecoveryContext {
  /// The original user request that initiated the agent plan.
  final String originalRequest;

  /// The current agent plan (may be a replanned version).
  final AgentPlan currentPlan;

  /// The step that failed (null if failure happened before a step).
  final AgentStep? failedStep;

  /// The failure that triggered recovery.
  final RecoveryFailure failure;

  /// List of previous recovery attempts (chronological order).
  final List<RecoveryAttempt> previousAttempts;

  /// List of steps that completed successfully before the failure.
  final List<AgentStep> successfulSteps;

  /// Current screen state description (from accessibility or capture).
  /// Null if screen state is unavailable.
  final String? screenState;

  /// The recovery strategy chosen for the current attempt.
  final RecoveryStrategy strategy;

  /// Total number of retries attempted so far for this step.
  final int retryCount;

  const RecoveryContext({
    required this.originalRequest,
    required this.currentPlan,
    this.failedStep,
    required this.failure,
    this.previousAttempts = const [],
    this.successfulSteps = const [],
    this.screenState,
    required this.strategy,
    this.retryCount = 0,
  });

  /// Whether any previous attempt was made.
  bool get hasPreviousAttempts => previousAttempts.isNotEmpty;

  /// Whether the maximum retry count has been reached.
  bool get hasExhaustedRetries => false; // Caller checks against RetryPolicy

  /// Number of previous attempts.
  int get attemptCount => previousAttempts.length;

  RecoveryContext copyWith({
    String? originalRequest,
    AgentPlan? currentPlan,
    AgentStep? failedStep,
    bool clearFailedStep = false,
    RecoveryFailure? failure,
    List<RecoveryAttempt>? previousAttempts,
    List<AgentStep>? successfulSteps,
    String? screenState,
    bool clearScreenState = false,
    RecoveryStrategy? strategy,
    int? retryCount,
  }) =>
      RecoveryContext(
        originalRequest: originalRequest ?? this.originalRequest,
        currentPlan: currentPlan ?? this.currentPlan,
        failedStep: clearFailedStep ? null : (failedStep ?? this.failedStep),
        failure: failure ?? this.failure,
        previousAttempts: previousAttempts ?? this.previousAttempts,
        successfulSteps: successfulSteps ?? this.successfulSteps,
        screenState:
            clearScreenState ? null : (screenState ?? this.screenState),
        strategy: strategy ?? this.strategy,
        retryCount: retryCount ?? this.retryCount,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecoveryContext &&
          originalRequest == other.originalRequest &&
          currentPlan == other.currentPlan &&
          failedStep == other.failedStep &&
          failure == other.failure &&
          retryCount == other.retryCount;

  @override
  int get hashCode => Object.hash(
        originalRequest,
        currentPlan,
        failedStep,
        failure,
        retryCount,
      );

  @override
  String toString() =>
      'RecoveryContext(request: $originalRequest, strategy: $strategy, retries: $retryCount)';
}
