/// default_replanning_engine.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Default implementation of ReplanningEngine.
/// Provides concrete failure recording, analysis, strategy
/// determination, and alternative plan generation.
///
/// Clean architecture: Infrastructure layer, implements Domain service.
///
/// Kurdish-first, local-first, privacy-conscious.
library;

import '../domain/models/agent_plan.dart';
import '../domain/models/recovery_context.dart';
import '../domain/models/recovery_failure.dart';
import '../domain/models/recovery_failure_phase.dart';
import '../domain/models/recovery_strategy.dart';
import '../domain/services/recovery_failure_classifier.dart';
import '../domain/services/replanning_engine.dart';
import '../../../core/errors/result.dart';

class DefaultReplanningEngine implements ReplanningEngine {
  final RecoveryFailureClassifier _classifier;

  const DefaultReplanningEngine({
    required RecoveryFailureClassifier classifier,
  }) : _classifier = classifier;

  @override
  RecoveryContext recordFailedStep(
    RecoveryContext context,
    AgentStep failedStep,
    RecoveryFailure failure,
  ) {
    final newAttempt = RecoveryAttempt(
      strategy: context.strategy,
      succeeded: false,
      failure: failure,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    return context.copyWith(
      failedStep: failedStep,
      failure: failure,
      previousAttempts: [...context.previousAttempts, newAttempt],
    );
  }

  @override
  RecoveryContext analyzeFailure(RecoveryContext context) {
    // Analyze the failure phase to determine characteristics
    final phase = context.failure.phase;
    final isRetryable = _classifier.isPhaseRetryable(phase);
    final defaultStrategy = _classifier.defaultStrategyForPhase(phase);

    // If the failure is not retryable and we haven't set a strategy yet,
    // use the default strategy for the phase
    if (!isRetryable &&
        context.strategy == RecoveryStrategy.retrySame &&
        defaultStrategy != RecoveryStrategy.retrySame) {
      return context.copyWith(strategy: defaultStrategy);
    }

    return context;
  }

  @override
  RecoveryStrategy determineRecoveryStrategy(RecoveryContext context) {
    final phase = context.failure.phase;

    // If retries are exhausted, abort
    if (context.retryCount >= 3) {
      // Hard upper limit check
      return RecoveryStrategy.abortSafely;
    }

    // If cancellation was requested, abort
    if (context.failure.phase == RecoveryFailurePhase.cancellation) {
      return RecoveryStrategy.abortSafely;
    }

    // Check previous attempts — if same strategy failed, escalate
    final lastAttempt = context.previousAttempts.isNotEmpty
        ? context.previousAttempts.last
        : null;

    if (lastAttempt != null && !lastAttempt.succeeded) {
      // Escalate strategy based on what already failed
      switch (lastAttempt.strategy) {
        case RecoveryStrategy.retrySame:
          return RecoveryStrategy.retryModified;
        case RecoveryStrategy.retryModified:
          return RecoveryStrategy.recaptureScreen;
        case RecoveryStrategy.recaptureScreen:
          return RecoveryStrategy.reunderstandScreen;
        case RecoveryStrategy.reunderstandScreen:
          return RecoveryStrategy.replan;
        case RecoveryStrategy.replan:
          return RecoveryStrategy.abortSafely;
        case RecoveryStrategy.waitAndRetry:
          return RecoveryStrategy.retrySame;
        case RecoveryStrategy.researchTarget:
          return RecoveryStrategy.recaptureScreen;
        case RecoveryStrategy.requestPermission:
          return RecoveryStrategy.abortSafely; // Can't force permissions
        case RecoveryStrategy.skipStep:
          return RecoveryStrategy.replan;
        case RecoveryStrategy.abortSafely:
          return RecoveryStrategy.abortSafely; // Already aborting
      }
    }

    // Default strategy for the phase
    return _classifier.defaultStrategyForPhase(phase);
  }

  @override
  RecoveryResult<AgentPlan> generateAlternativePlan(
    RecoveryContext context,
  ) {
    if (!canReplan(context)) {
      return Result.failure(RecoveryFailure.unsupportedAction(
        'Cannot replan: retries exhausted or cancellation requested',
      ));
    }

    // Preserve successful steps and replan remaining
    final successfulSteps = preserveSuccessfulSteps(context);
    final currentPlan = context.currentPlan;

    // Create a new plan with the same goal but adjusted steps
    // In production, this would invoke the agent to re-generate steps.
    // For this implementation, we re-index remaining steps after
    // the failure point and advance the plan.
    final newStepIndex = (context.failedStep?.index ?? currentPlan.currentStepIndex) + 1;

    final newPlan = currentPlan.copyWith(
      currentStepIndex: newStepIndex,
    );

    return Result.success(newPlan);
  }

  @override
  List<AgentStep> preserveSuccessfulSteps(RecoveryContext context) {
    return context.successfulSteps;
  }

  @override
  bool canReplan(RecoveryContext context) {
    // Cannot replan if:
    // 1. Retries exhausted (hard limit)
    if (context.retryCount >= 3) return false;
    // 2. Cancellation requested
    if (context.failure.phase == RecoveryFailurePhase.cancellation) {
      return false;
    }
    // 3. Strategy is abort
    if (context.strategy == RecoveryStrategy.abortSafely) return false;

    return true;
  }
}
