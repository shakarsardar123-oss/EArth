/// replanning_engine.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Abstract service interface for the replanning engine.
/// Provides methods to record failures, analyze them,
/// determine recovery strategies, generate alternative plans,
/// and preserve successful steps.
///
/// Clean architecture: Domain layer, no infrastructure dependencies.
///
/// Kurdish-first, local-first, privacy-conscious.
library;

import '../models/agent_plan.dart';
import '../models/recovery_context.dart';
import '../models/recovery_failure.dart';
import '../models/recovery_strategy.dart';

/// Abstract replanning engine service.
///
/// Responsible for:
/// 1. Recording failed steps in the plan
/// 2. Analyzing failures to determine root cause
/// 3. Determining the best recovery strategy
/// 4. Generating alternative plans when replanning is needed
/// 5. Preserving successful steps when replanning
abstract class ReplanningEngine {
  /// Record a failed step in the recovery context.
  ///
  /// Returns an updated [RecoveryContext] with the failure recorded.
  RecoveryContext recordFailedStep(
    RecoveryContext context,
    AgentStep failedStep,
    RecoveryFailure failure,
  );

  /// Analyze a failure to determine its cause and characteristics.
  ///
  /// Returns an updated [RecoveryContext] with analysis results.
  RecoveryContext analyzeFailure(RecoveryContext context);

  /// Determine the best recovery strategy for the current failure.
  ///
  /// Takes into account:
  /// - Failure phase and retryability
  /// - Number of previous attempts
  /// - Available strategies
  /// - Cancellation state
  RecoveryStrategy determineRecoveryStrategy(RecoveryContext context);

  /// Generate an alternative plan based on the recovery context.
  ///
  /// Preserves successful steps and replans from the failure point.
  /// Returns a [RecoveryResult] with the new plan or a failure
  /// if replanning is not possible.
  RecoveryResult<AgentPlan> generateAlternativePlan(
    RecoveryContext context,
  );

  /// Preserve successfully completed steps when replanning.
  ///
  /// Extracts the successful portion of the current plan
  /// so it can be included in the replanned version.
  List<AgentStep> preserveSuccessfulSteps(RecoveryContext context);

  /// Check if replanning is possible for the given context.
  ///
  /// Returns false if:
  /// - Retries are exhausted
  /// - Cancellation is requested
  /// - The failure is non-retryable and strategy is abortSafely
  bool canReplan(RecoveryContext context);
}
