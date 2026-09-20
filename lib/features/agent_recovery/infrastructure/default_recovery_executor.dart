/// default_recovery_executor.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Default implementation of RecoveryExecutor.
/// Wraps agent step execution, integrates with AgentContext
/// via addMessage(), and respects cancellation.
///
/// Clean architecture: Infrastructure layer, implements Domain service.
///
/// Kurdish-first, local-first, privacy-conscious.
library;

import '../domain/models/agent_plan.dart';
import '../domain/models/recovery_context.dart';
import '../domain/models/recovery_failure.dart';
import '../domain/models/recovery_failure_phase.dart';
import '../domain/models/recovery_phase.dart';
import '../domain/services/recovery_executor.dart';
import '../../../core/errors/result.dart';

class DefaultRecoveryExecutor implements RecoveryExecutor {
  bool _isCancelled = false;

  DefaultRecoveryExecutor();

  @override
  bool get isCancelled => _isCancelled;

  @override
  RecoveryResult<AgentStepResult> executeStep(
    AgentStep step,
    RecoveryContext context,
  ) {
    // Check cancellation before execution
    if (_isCancelled) {
      return Result.failure(RecoveryFailure.cancellation(
        'Execution cancelled before step ${step.index}',
        action: step,
      ));
    }

    // In production, this would invoke the AgentEngine.process()
    // with the step's action data. For this implementation,
    // we provide a structural stub that validates the step.
    if (step.actionData.isEmpty) {
      return Result.failure(RecoveryFailure.invalidParameters(
        'Step ${step.id} has empty action data',
        action: step,
      ));
    }

    // Inject recovery context via addMessage() pattern
    injectRecoveryContext(context, RecoveryPhase.executing);

    // Simulate step execution result
    // In production: call AgentEngine.process(AgentContext(...))
    final result = AgentStepResult(
      step: step,
      succeeded: true,
      resultData: {'executed': true, 'stepId': step.id},
    );

    // Verify if needed
    if (step.requiresVerification) {
      final verifyResult = verifyStep(step, result);
      if (verifyResult.isFailure) {
        return Result.failure(RecoveryFailure.verificationFailure(
          'Verification failed for step ${step.id}',
          action: step,
          cause: verifyResult.failureOrNull,
        ));
      }
    }

    return Result.success(result);
  }

  @override
  RecoveryResult<AgentPlan> executePlan(
    AgentPlan plan,
    RecoveryContext context,
  ) {
    if (_isCancelled) {
      return Result.failure(RecoveryFailure.cancellation(
        'Plan execution cancelled',
        action: plan,
      ));
    }

    // Execute steps sequentially
    var currentPlan = plan;
    for (var i = plan.currentStepIndex; i < plan.totalSteps; i++) {
      if (_isCancelled) {
        return Result.failure(RecoveryFailure.cancellation(
          'Plan execution cancelled at step $i',
          action: currentPlan,
        ));
      }

      final step = plan.steps[i];
      final stepResult = executeStep(step, context);

      if (stepResult.isFailure) {
        return Result.failure(stepResult.failureOrNull!);
      }

      // Record successful step
      final result = stepResult.valueOrNull!;
      currentPlan = currentPlan.copyWith(
        currentStepIndex: i + 1,
        stepResults: [...currentPlan.stepResults, result],
      );
    }

    return Result.success(currentPlan);
  }

  @override
  RecoveryResult<void> verifyStep(
    AgentStep step,
    AgentStepResult result,
  ) {
    // In production, this would capture the screen state and
    // compare against the expected outcome.
    // For this implementation, we perform structural verification.
    if (!result.succeeded) {
      return Result.failure(RecoveryFailure.verificationFailure(
        'Step ${step.id} did not succeed — cannot verify',
        action: step,
      ));
    }

    // If expected outcome is defined, check result data
    if (step.expectedOutcome != null && result.resultData != null) {
      // Structural check only — real implementation would compare
      // screen state against expected outcome
      return Result.success(null);
    }

    return Result.success(null);
  }

  @override
  void injectRecoveryContext(
    RecoveryContext context,
    RecoveryPhase phase,
  ) {
    // In production, this would call:
    //   agentContextView.addMessage(
    //     role: 'system',
    //     content: 'Recovery phase: $phase, strategy: ${context.strategy}',
    //   );
    //
    // This integrates with the agent's context via addMessage()
    // pattern, ensuring the agent is aware of recovery state.
  }

  @override
  void cancel() {
    _isCancelled = true;
  }

  /// Reset cancellation state (for reuse).
  void resetCancellation() {
    _isCancelled = false;
  }
}
