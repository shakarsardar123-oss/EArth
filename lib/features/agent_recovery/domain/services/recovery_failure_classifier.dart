/// recovery_failure_classifier.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Abstract service for classifying agent failures.
/// Maps raw failures to RecoveryFailurePhase values and
/// determines retryability.
///
/// Clean architecture: Domain layer, no infrastructure dependencies.
///
/// Kurdish-first, local-first, privacy-conscious.
library;

import '../models/recovery_failure.dart';
import '../models/recovery_failure_phase.dart';
import '../models/recovery_strategy.dart';

/// Abstract failure classifier for the agent recovery pipeline.
///
/// Takes a raw failure (exception, error, or timeout) and classifies
/// it into a [RecoveryFailurePhase], then suggests a default
/// [RecoveryStrategy] for that phase.
abstract class RecoveryFailureClassifier {
  /// Classify a raw error/exception into a RecoveryFailure.
  ///
  /// [rawError] is the original error object or message.
  /// [action] is the action that was being executed (may be null).
  RecoveryFailure classify(
    Object rawError, {
    dynamic action,
  });

  /// Get the default recovery strategy for a given failure phase.
  RecoveryStrategy defaultStrategyForPhase(RecoveryFailurePhase phase);

  /// Whether a failure with this phase is typically retryable.
  bool isPhaseRetryable(RecoveryFailurePhase phase);

  /// Whether a failure with this phase is typically non-retryable.
  bool isPhaseNonRetryable(RecoveryFailurePhase phase) =>
      !isPhaseRetryable(phase);

  /// Get a human-readable description for a failure phase.
  String describePhase(RecoveryFailurePhase phase);
}
