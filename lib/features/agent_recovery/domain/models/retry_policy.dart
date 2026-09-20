/// retry_policy.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Immutable retry policy with hard upper limits, exponential
/// backoff, cancellation support, and per-step/total tracking.
///
/// Rules:
///   - Never allow infinite retries; hard upper limit (default 3)
///   - Every retry passes through normal validation/execution pipeline
///   - Cancellation immediately stops all retry/replan
///   - Verification-aware: verification failure triggers classification
///
/// Kurdish-first, local-first, privacy-conscious.
library;

import 'package:meta/meta.dart';
import 'recovery_failure_phase.dart';

/// Configuration for exponential backoff between retries.
@immutable
class ExponentialBackoffConfig {
  /// Initial delay in milliseconds before the first retry.
  final int initialDelayMs;

  /// Multiplier applied to delay after each retry (e.g. 2.0 = double).
  final double multiplier;

  /// Maximum delay in milliseconds (cap to prevent excessive waits).
  final int maxDelayMs;

  /// Whether to add jitter to the delay (recommended for network retries).
  final bool withJitter;

  const ExponentialBackoffConfig({
    this.initialDelayMs = 1000,
    this.multiplier = 2.0,
    this.maxDelayMs = 30000,
    this.withJitter = true,
  });

  /// Calculate the delay for the given retry attempt number (0-based).
  int delayForAttempt(int attemptNumber) {
    final rawDelay = (initialDelayMs * (multiplier.pow(attemptNumber))).toInt();
    final capped = rawDelay > maxDelayMs ? maxDelayMs : rawDelay;
    if (withJitter && capped > 0) {
      // Add ±20% jitter
      final jitterRange = (capped * 0.2).toInt();
      final jitter =
          attemptNumber * 31 % (jitterRange + 1) - jitterRange ~/ 2;
      final withJitterDelay = capped + jitter;
      return withJitterDelay < 0 ? 0 : withJitterDelay;
    }
    return capped;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExponentialBackoffConfig &&
          initialDelayMs == other.initialDelayMs &&
          multiplier == other.multiplier &&
          maxDelayMs == other.maxDelayMs &&
          withJitter == other.withJitter;

  @override
  int get hashCode =>
      Object.hash(initialDelayMs, multiplier, maxDelayMs, withJitter);

  @override
  String toString() =>
      'ExponentialBackoffConfig(initial: ${initialDelayMs}ms, '
      'multiplier: $multiplier, max: ${maxDelayMs}ms, jitter: $withJitter)';
}

/// Immutable retry policy governing recovery retry behavior.
///
/// Enforces hard upper limits — never allows infinite retries.
/// Tracks both per-step and total retry counts.
@immutable
class RetryPolicy {
  /// Maximum retries for a single step before giving up.
  /// Hard upper limit — never infinite.
  final int maxRetriesPerStep;

  /// Maximum total retries across the entire plan before aborting.
  final int maxTotalRetries;

  /// Current retry count for the current step.
  final int currentStepRetries;

  /// Current total retry count across all steps.
  final int currentTotalRetries;

  /// Exponential backoff configuration.
  final ExponentialBackoffConfig backoffConfig;

  /// Failure phases that are retryable (default: most transient phases).
  final Set<RecoveryFailurePhase> retryablePhases;

  /// Whether cancellation has been requested.
  final bool isCancelled;

  /// Default constructor.
  const RetryPolicy({
    this.maxRetriesPerStep = 3,
    this.maxTotalRetries = 10,
    this.currentStepRetries = 0,
    this.currentTotalRetries = 0,
    this.backoffConfig = const ExponentialBackoffConfig(),
    this.retryablePhases = const {
      RecoveryFailurePhase.toolFailure,
      RecoveryFailurePhase.timeout,
      RecoveryFailurePhase.screenStateChanged,
      RecoveryFailurePhase.verificationFailure,
      RecoveryFailurePhase.networkFailure,
      RecoveryFailurePhase.targetNotFound,
    },
    this.isCancelled = false,
  });

  /// Whether a failure with the given phase is retryable.
  bool isRetryable(RecoveryFailurePhase phase) {
    if (isCancelled) return false;
    return retryablePhases.contains(phase);
  }

  /// Whether a failure with the given phase is non-retryable.
  bool isNonRetryable(RecoveryFailurePhase phase) =>
      !isRetryable(phase);

  /// Whether the per-step retry limit has been reached.
  bool get hasStepRetriesExhausted =>
      currentStepRetries >= maxRetriesPerStep;

  /// Whether the total retry limit has been reached.
  bool get hasTotalRetriesExhausted =>
      currentTotalRetries >= maxTotalRetries;

  /// Whether any more retries are possible.
  bool get canRetry =>
      !isCancelled &&
      !hasStepRetriesExhausted &&
      !hasTotalRetriesExhausted;

  /// Calculate the backoff delay for the next retry (in ms).
  int get nextRetryDelayMs =>
      backoffConfig.delayForAttempt(currentStepRetries);

  /// Create an incremented policy (after a retry attempt on the same step).
  RetryPolicy incrementStepRetry() => copyWith(
        currentStepRetries: currentStepRetries + 1,
        currentTotalRetries: currentTotalRetries + 1,
      );

  /// Reset step retries (when moving to a new step).
  RetryPolicy resetStepRetries() => copyWith(
        currentStepRetries: 0,
      );

  /// Mark the policy as cancelled — stops all future retries.
  RetryPolicy cancel() => copyWith(isCancelled: true);

  RetryPolicy copyWith({
    int? maxRetriesPerStep,
    int? maxTotalRetries,
    int? currentStepRetries,
    int? currentTotalRetries,
    ExponentialBackoffConfig? backoffConfig,
    Set<RecoveryFailurePhase>? retryablePhases,
    bool? isCancelled,
  }) =>
      RetryPolicy(
        maxRetriesPerStep: maxRetriesPerStep ?? this.maxRetriesPerStep,
        maxTotalRetries: maxTotalRetries ?? this.maxTotalRetries,
        currentStepRetries: currentStepRetries ?? this.currentStepRetries,
        currentTotalRetries: currentTotalRetries ?? this.currentTotalRetries,
        backoffConfig: backoffConfig ?? this.backoffConfig,
        retryablePhases: retryablePhases ?? this.retryablePhases,
        isCancelled: isCancelled ?? this.isCancelled,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RetryPolicy &&
          maxRetriesPerStep == other.maxRetriesPerStep &&
          maxTotalRetries == other.maxTotalRetries &&
          currentStepRetries == other.currentStepRetries &&
          currentTotalRetries == other.currentTotalRetries &&
          isCancelled == other.isCancelled;

  @override
  int get hashCode => Object.hash(
        maxRetriesPerStep,
        maxTotalRetries,
        currentStepRetries,
        currentTotalRetries,
        isCancelled,
      );

  @override
  String toString() =>
      'RetryPolicy(perStep: $currentStepRetries/$maxRetriesPerStep, '
      'total: $currentTotalRetries/$maxTotalRetries, cancelled: $isCancelled)';
}

/// Extension on double for integer power (avoid importing dart:math).
extension _IntPow on double {
  int pow(int exponent) {
    if (exponent == 0) return 1;
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= this;
    }
    return result.toInt();
  }
}
