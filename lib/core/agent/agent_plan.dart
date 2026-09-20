import '../utils/uuid_util.dart';

import 'agent_step.dart';
import 'agent_step_status.dart';
import 'retry_policy.dart';

/// A plan consisting of ordered steps the agent will execute.
///
/// Phase 4 adds: planId, goal, dependencies, expectedResults,
/// verificationConditions, retryPolicy — all with defaults for backward compat.
class AgentPlan {
  AgentPlan({
    required this.steps,
    this.reasoning,
    // ── Phase 4 additions ──
    String? planId,
    this.goal,
    this.dependencies = const {},
    this.expectedResults = const [],
    this.verificationConditions = const [],
    this.retryPolicy,
    DateTime? createdAt,
  })  : planId = planId ?? UuidUtil().v4(),
        createdAt = createdAt ?? DateTime.now();

  // ── Original fields (Phase 1–3) ──
  final List<AgentStep> steps;
  final String? reasoning;

  // ── Phase 4 additions ──
  final String planId;

  /// High-level goal this plan is trying to achieve.
  final String? goal;

  /// Step dependency map: `stepId` → `Set<stepId>` it depends on.
  final Map<String, Set<String>> dependencies;

  /// What the overall plan is expected to produce.
  final List<String> expectedResults;

  /// Conditions that must hold for plan to be considered verified.
  final List<String> verificationConditions;

  /// Retry policy for steps in this plan.
  final RetryPolicy? retryPolicy;

  /// When this plan was created.
  final DateTime createdAt;

  // ── Original computed properties (preserved) ──
  bool get isEmpty => steps.isEmpty;
  bool get isNotEmpty => steps.isNotEmpty;
  int get length => steps.length;

  /// Steps that have not yet been executed.
  Iterable<AgentStep> get pending =>
      steps.where((s) => s.status == AgentStepStatus.pending);

  /// Steps that have been executed (any terminal status).
  Iterable<AgentStep> get completed =>
      steps.where((s) => s.status.isDone);

  /// Whether all steps are done.
  bool get isComplete => steps.every((s) => s.status.isDone);

  /// Whether all completed steps succeeded (no failures/skips).
  bool get allSucceeded =>
      steps.every((s) => s.status == AgentStepStatus.succeeded);

  /// Steps that have failed.
  Iterable<AgentStep> get failedSteps =>
      steps.where((s) => s.status == AgentStepStatus.failed);

  /// Whether any step has failed.
  bool get hasFailures => failedSteps.isNotEmpty;

  /// Steps that are currently running.
  Iterable<AgentStep> get running =>
      steps.where((s) => s.status == AgentStepStatus.running);

  /// Get the step by its stepId, or null if not found.
  AgentStep? getStepById(String stepId) {
    for (final step in steps) {
      if (step.stepId == stepId) return step;
    }
    return null;
  }

  /// Whether a step's dependencies are all completed successfully.
  bool areDependenciesMet(AgentStep step) {
    final deps = dependencies[step.stepId];
    if (deps == null || deps.isEmpty) return true;
    return deps.every((depId) {
      final dep = getStepById(depId);
      return dep != null && dep.status == AgentStepStatus.succeeded;
    });
  }

  /// Get steps ready to execute (pending + deps met).
  Iterable<AgentStep> get readySteps =>
      steps.where((s) => s.status == AgentStepStatus.pending && areDependenciesMet(s));

  /// Replace a step in-place (by stepId match).
  AgentPlan replaceStep(AgentStep newStep) {
    return AgentPlan(
      steps: steps.map((s) => s.stepId == newStep.stepId ? newStep : s).toList(),
      reasoning: reasoning,
      planId: planId,
      goal: goal,
      dependencies: dependencies,
      expectedResults: expectedResults,
      verificationConditions: verificationConditions,
      retryPolicy: retryPolicy,
      createdAt: createdAt,
    );
  }

  /// Add a step to the plan.
  AgentPlan addStep(AgentStep step) {
    return AgentPlan(
      steps: [...steps, step],
      reasoning: reasoning,
      planId: planId,
      goal: goal,
      dependencies: dependencies,
      expectedResults: expectedResults,
      verificationConditions: verificationConditions,
      retryPolicy: retryPolicy,
      createdAt: createdAt,
    );
  }

  /// Create a revised plan preserving completed steps.
  AgentPlan revise({
    List<AgentStep>? newSteps,
    String? newReasoning,
    String? newGoal,
    Map<String, Set<String>>? newDependencies,
    List<String>? newExpectedResults,
    List<String>? newVerificationConditions,
    RetryPolicy? newRetryPolicy,
  }) {
    final keptSteps =
        steps.where((s) => s.status == AgentStepStatus.succeeded).toList();
    return AgentPlan(
      steps: [...keptSteps, ...(newSteps ?? [])],
      reasoning: newReasoning ?? reasoning,
      planId: planId, // same planId — it's a revision
      goal: newGoal ?? goal,
      dependencies: newDependencies ?? dependencies,
      expectedResults: newExpectedResults ?? expectedResults,
      verificationConditions:
          newVerificationConditions ?? verificationConditions,
      retryPolicy: newRetryPolicy ?? retryPolicy,
      createdAt: createdAt,
    );
  }

  AgentPlan copyWith({
    List<AgentStep>? steps,
    String? reasoning,
    String? goal,
    Map<String, Set<String>>? dependencies,
    List<String>? expectedResults,
    List<String>? verificationConditions,
    RetryPolicy? retryPolicy,
  }) {
    return AgentPlan(
      steps: steps ?? this.steps,
      reasoning: reasoning ?? this.reasoning,
      goal: goal ?? this.goal,
      dependencies: dependencies ?? this.dependencies,
      expectedResults: expectedResults ?? this.expectedResults,
      verificationConditions:
          verificationConditions ?? this.verificationConditions,
      retryPolicy: retryPolicy ?? this.retryPolicy,
    );
  }

  @override
  String toString() =>
      'AgentPlan($planId, steps: ${steps.length}, goal: $goal, complete: $isComplete)';
}
