import 'agent_context.dart';
import 'agent_plan.dart';
import 'agent_step.dart';
import 'agent_step_status.dart';
import 'agent_recovery.dart';

/// Result of a replanning operation.
class ReplanResult {
  const ReplanResult({
    required this.revisedPlan,
    required this.preservedSteps,
    required this.removedSteps,
    required this.addedSteps,
    required this.reason,
  });

  /// The new plan.
  final AgentPlan revisedPlan;

  /// Steps carried over from the old plan (succeeded/skipped).
  final List<AgentStep> preservedSteps;

  /// Steps removed from the old plan.
  final List<AgentStep> removedSteps;

  /// Steps added to the new plan.
  final List<AgentStep> addedSteps;

  /// Why replanning was triggered.
  final String reason;

  @override
  String toString() =>
      'ReplanResult(preserved: ${preservedSteps.length}, '
      'removed: ${removedSteps.length}, added: ${addedSteps.length})';
}

/// Replanning module — revises a plan when execution hits obstacles.
///
/// Phase 4 replanning:
/// - Analyzes observations to understand what went wrong
/// - Preserves all succeeded/skipped steps
/// - Replaces failed steps with alternative actions
/// - Maintains plan goal and verification conditions
class AgentReplanning {
  /// Revise a plan based on observations and recovery decision.
  ///
  /// This uses the plan's built-in `revise()` method to preserve succeeded
  /// steps, then adds replacement steps for the failed ones.
  ReplanResult revise(
    AgentPlan originalPlan,
    AgentContext context,
    RecoveryDecision recoveryDecision,
  ) {
    // Collect failed step IDs to remove.
    final failedStepIds = <String>{};
    final removedSteps = <AgentStep>[];
    for (final step in originalPlan.steps) {
      if (step.status == AgentStepStatus.failed) {
        failedStepIds.add(step.stepId);
        removedSteps.add(step);
      }
    }

    // Use the plan's revise() method — it preserves succeeded steps.
    // NOTE: AgentPlan is immutable — addStep() returns a NEW AgentPlan.
    // We must reassign the variable after each addStep() call.
    var revisedPlan = originalPlan.revise();

    // For each failed step, create an alternative step if possible.
    final addedSteps = <AgentStep>[];
    for (final failedStep in removedSteps) {
      final alternative = _createAlternativeStep(failedStep, context);
      if (alternative != null) {
        revisedPlan = revisedPlan.addStep(alternative);
        addedSteps.add(alternative);
      }
    }

    // Preserve the goal and verification conditions.
    // (revise() already preserves the goal from originalPlan)

    return ReplanResult(
      revisedPlan: revisedPlan,
      preservedSteps: revisedPlan.steps
          .where((s) => s.status == AgentStepStatus.succeeded)
          .toList(),
      removedSteps: removedSteps,
      addedSteps: addedSteps,
      reason: recoveryDecision.reason,
    );
  }

  /// Analyze observations to determine if replanning is needed.
  bool shouldReplan(List<AgentObservation> observations) {
    // Replan if any observation indicates an unexpected result.
    for (final obs in observations) {
      if (obs.summary.toLowerCase().contains('failed') ||
          obs.summary.toLowerCase().contains('error') ||
          obs.summary.toLowerCase().contains('not found') ||
          obs.summary.toLowerCase().contains('unavailable')) {
        return true;
      }
    }
    return false;
  }

  /// Create an alternative step for a failed step.
  AgentStep? _createAlternativeStep(
    AgentStep failedStep,
    AgentContext context,
  ) {
    // If the failed step used a specific tool, try an alternative tool
    // or modified approach.
    final toolName = failedStep.toolName;

    // For now, create a generic fallback step.
    // In a full LLM-guided implementation, the planner would generate
    // a more intelligent alternative.
    return AgentStep(
      toolName: toolName,
      description: '${failedStep.description} (دووبارە هەوڵ — alternative)',
      parameters: Map<String, dynamic>.from(failedStep.parameters),
      maxRetries: 1, // Reduced retries for alternative step.
    );
  }
}
