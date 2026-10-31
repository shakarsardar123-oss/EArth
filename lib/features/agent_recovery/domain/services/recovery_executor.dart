/// recovery_executor.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Abstract service for executing agent steps with recovery support.
/// Wraps the agent execution pipeline, integrates with AgentContext
/// via addMessage(), and respects cancellation.
///
/// Clean architecture: Domain layer, no infrastructure dependencies.
///
/// Kurdish-first, local-first, privacy-conscious.
library;

import '../models/agent_plan.dart';
import '../models/recovery_context.dart';
import '../models/recovery_failure.dart';
import '../models/recovery_phase.dart';

/// Callback for phase changes during recovery execution.
typedef RecoveryPhaseCallback = void Function(RecoveryPhase phase);

/// Callback for step completion during recovery execution.
typedef RecoveryStepCallback = void Function(
  AgentStep step,
  bool succeeded,
  String? errorMessage,
);

/// Abstract recovery executor service.
///
/// Executes agent steps with integrated recovery:
/// 1. Executes a step through the normal validation/execution pipeline
/// 2. Verifies the result (if verification is required)
/// 3. On failure, triggers the recovery pipeline
/// 4. Integrates with AgentContext via addMessage()
/// 5. Respects cancellation — immediately stops on cancel
abstract class RecoveryExecutor {
  /// Execute a single agent step.
  ///
  /// Returns the step result on success, or a RecoveryFailure on failure.
  /// Checks cancellation before execution.
  RecoveryResult<AgentStepResult> executeStep(
    AgentStep step,
    RecoveryContext context,
  );

  /// Execute a full agent plan with recovery support.
  ///
  /// Executes steps sequentially, applying recovery on failures.
  /// Returns the final plan state or a failure if execution aborts.
  RecoveryResult<AgentPlan> executePlan(
    AgentPlan plan,
    RecoveryContext context,
  );

  /// Verify the result of a step execution.
  ///
  /// Verification-aware: if the action succeeded but verification
  /// fails, this classifies the failure and returns it.
  RecoveryResult<void> verifyStep(
    AgentStep step,
    AgentStepResult result,
  );

  /// Inject recovery context into the agent context.
  ///
  /// Uses addMessage() to communicate recovery state to the agent.
  void injectRecoveryContext(
    RecoveryContext context,
    RecoveryPhase phase,
  );

  /// Cancel the current execution.
  ///
  /// Immediately stops all retry/replan operations.
  void cancel();

  /// Whether execution is currently cancelled.
  bool get isCancelled;
}
