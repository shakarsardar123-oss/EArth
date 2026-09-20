import 'agent_context.dart';
import 'agent_plan.dart';
import 'agent_step.dart';
import 'agent_verification_engine.dart';
import 'retry_policy.dart';

/// Recovery strategy chosen after a failure.
enum RecoveryStrategy {
  /// Just retry the same step with same arguments.
  retry,

  /// Retry with modified arguments (e.g. fallback value).
  retryWithModification,

  /// Skip this step and continue (if it's not critical).
  skip,

  /// Replan from this point — create a new plan preserving succeeded steps.
  replan,

  /// Abort the entire plan — cannot recover.
  abort;

  /// Whether this strategy allows continuation.
  bool get canContinue =>
      this == RecoveryStrategy.retry ||
      this == RecoveryStrategy.retryWithModification ||
      this == RecoveryStrategy.skip ||
      this == RecoveryStrategy.replan;
}

/// Decision made by the recovery module.
class RecoveryDecision {
  const RecoveryDecision({
    required this.strategy,
    required this.reason,
    this.modifiedArguments,
    this.maxAdditionalRetries = 0,
    this.newPlan,
    this.userMessage,
  });

  /// The chosen recovery strategy.
  final RecoveryStrategy strategy;

  /// Why this strategy was chosen.
  final String reason;

  /// If retryWithModification, the new arguments to use.
  final Map<String, dynamic>? modifiedArguments;

  /// Extra retries allowed beyond the step's own maxRetries.
  final int maxAdditionalRetries;

  /// If replan, the revised plan.
  final AgentPlan? newPlan;

  /// Optional message to show the user (Kurdish Sorani).
  final String? userMessage;

  @override
  String toString() =>
      'RecoveryDecision($strategy: $reason)';
}

/// Bounded retry and recovery module.
///
/// Phase 4 recovery handles:
/// - Classifying failures (transient, permanent, resource, permission, timeout)
/// - Deciding recovery strategy based on failure type + retry budget
/// - Bounded retries (max 3 global across plan)
/// - Delegating to replanning module when appropriate
class AgentRecovery {
  /// Maximum total retries across the entire plan.
  static const int globalMaxRetries = 3;

  /// Decide recovery strategy for a failed step.
  RecoveryDecision decide(
    AgentStep failedStep,
    AgentContext context,
    VerificationResult? verificationResult,
  ) {
    final failureClass = _classifyFailure(failedStep, verificationResult);

    // Check global retry budget.
    if (context.retryCount >= globalMaxRetries) {
      return RecoveryDecision(
        strategy: RecoveryStrategy.abort,
        reason: 'Global retry budget exhausted (${context.retryCount}/$globalMaxRetries)',
        userMessage: 'هەڵە زۆر بوو، ناتوانم دووبارە هەوڵ بدەمەوە',
      );
    }

    // Check step-level retry budget.
    if (failedStep.retryCount >= failedStep.maxRetries) {
      return _decideBeyondStepRetries(
        failedStep,
        failureClass,
        context,
      );
    }

    // Step still has retry budget — decide based on failure type.
    switch (failureClass) {
      case FailureClassification.temporary:
      case FailureClassification.transient:
        return const RecoveryDecision(
          strategy: RecoveryStrategy.retry,
          reason: 'Transient failure — safe to retry',
          maxAdditionalRetries: 1,
        );

      case FailureClassification.timeout:
        return const RecoveryDecision(
          strategy: RecoveryStrategy.retry,
          reason: 'Timeout — may succeed on retry',
          maxAdditionalRetries: 1,
        );

      case FailureClassification.validation:
        return const RecoveryDecision(
          strategy: RecoveryStrategy.replan,
          reason: 'Validation failed — need different arguments',
          userMessage: 'داتای نادروست، پلان دەگۆڕم',
        );

      case FailureClassification.unsupported:
        return const RecoveryDecision(
          strategy: RecoveryStrategy.abort,
          reason: 'Unsupported operation — cannot proceed',
          userMessage: 'ئەم کردارە پشتگیری ناکرێت',
        );

      case FailureClassification.resource:
        return const RecoveryDecision(
          strategy: RecoveryStrategy.replan,
          reason: 'Resource unavailable — need different approach',
          userMessage: 'سەرچاوە بەردەست نییە، پلان دەگۆڕم',
        );

      case FailureClassification.permission:
        return const RecoveryDecision(
          strategy: RecoveryStrategy.abort,
          reason: 'Permission denied — cannot retry without user grant',
          userMessage: 'ڕێگەپێدان پێویستە، ناتوانم بەردەوام بم',
        );

      case FailureClassification.permanent:
        return _decideBeyondStepRetries(
          failedStep,
          failureClass,
          context,
        );
    }
  }

  /// Decide what to do when step retries are exhausted.
  RecoveryDecision _decideBeyondStepRetries(
    AgentStep failedStep,
    FailureClassification failureClass,
    AgentContext context,
  ) {
    // If this step is not the only way, try replanning.
    if (context.plan != null &&
        failureClass != FailureClassification.permission) {
      return const RecoveryDecision(
        strategy: RecoveryStrategy.replan,
        reason: 'Step retries exhausted — trying alternative approach',
        userMessage: 'هەوڵی تر دەدەم',
      );
    }

    return const RecoveryDecision(
      strategy: RecoveryStrategy.abort,
      reason: 'Step retries exhausted and no alternatives',
      userMessage: 'ناتوانم ئەم کارە بکەم',
    );
  }

  /// Classify the type of failure.
  FailureClassification _classifyFailure(
    AgentStep step,
    VerificationResult? verificationResult,
  ) {
    final error = step.error;
    if (error != null) {
      final errorStr = error.toString().toLowerCase();

      // Timeout patterns.
      if (errorStr.contains('timeout') ||
          errorStr.contains('timed out')) {
        return FailureClassification.timeout;
      }

      // Permission patterns.
      if (errorStr.contains('permission') ||
          errorStr.contains('denied') ||
          errorStr.contains('unauthorized')) {
        return FailureClassification.permission;
      }

      // Resource patterns.
      if (errorStr.contains('unavailable') ||
          errorStr.contains('not found') ||
          errorStr.contains('does not exist')) {
        return FailureClassification.resource;
      }

      // Network / transient patterns.
      if (errorStr.contains('network') ||
          errorStr.contains('connection') ||
          errorStr.contains('socket')) {
        return FailureClassification.transient;
      }
    }

    // If verification failed with critical severity, it's permanent.
    if (verificationResult != null &&
        !verificationResult.passed &&
        verificationResult.severity == VerificationSeverity.critical) {
      return FailureClassification.permanent;
    }

    // Default to transient — optimistic approach.
    return FailureClassification.transient;
  }

  /// Whether we can still recover (global budget not exhausted).
  bool canRecover(AgentContext context) =>
      context.retryCount < globalMaxRetries;
}
