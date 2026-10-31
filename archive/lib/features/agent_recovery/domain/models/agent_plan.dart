/// agent_plan.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Agent plan and step domain models.
/// These are NEW types created by Step 18 — they represent
/// a multi-step agent execution plan with individual steps.
///
/// Kurdish-first, local-first, privacy-conscious.
library;

import 'package:meta/meta.dart';

/// A single step in an agent execution plan.
///
/// Each step represents one atomic action the agent must perform,
/// such as tapping a button, entering text, or scrolling.
@immutable
class AgentStep {
  /// Unique identifier for this step within its plan.
  final String id;

  /// Human-readable description of what this step does.
  final String description;

  /// The action data (e.g. tap coordinates, text input, scroll params).
  /// Stored as a Map to allow flexible action types.
  final Map<String, dynamic> actionData;

  /// Whether this step requires post-action verification.
  final bool requiresVerification;

  /// Optional expected outcome description for verification.
  final String? expectedOutcome;

  /// Step index in the plan (0-based).
  final int index;

  const AgentStep({
    required this.id,
    required this.description,
    required this.actionData,
    this.requiresVerification = true,
    this.expectedOutcome,
    required this.index,
  });

  AgentStep copyWith({
    String? id,
    String? description,
    Map<String, dynamic>? actionData,
    bool? requiresVerification,
    String? expectedOutcome,
    int? index,
  }) =>
      AgentStep(
        id: id ?? this.id,
        description: description ?? this.description,
        actionData: actionData ?? this.actionData,
        requiresVerification: requiresVerification ?? this.requiresVerification,
        expectedOutcome: expectedOutcome ?? this.expectedOutcome,
        index: index ?? this.index,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentStep &&
          id == other.id &&
          index == other.index;

  @override
  int get hashCode => Object.hash(id, index);

  @override
  String toString() => 'AgentStep(id: $id, index: $index, description: $description)';
}

/// Result of executing a single agent step.
@immutable
class AgentStepResult {
  /// The step that was executed.
  final AgentStep step;

  /// Whether the step execution succeeded.
  final bool succeeded;

  /// Optional result data from the step execution.
  final Map<String, dynamic>? resultData;

  /// Optional error message if the step failed.
  final String? errorMessage;

  const AgentStepResult({
    required this.step,
    required this.succeeded,
    this.resultData,
    this.errorMessage,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentStepResult &&
          step == other.step &&
          succeeded == other.succeeded;

  @override
  int get hashCode => Object.hash(step, succeeded);

  @override
  String toString() =>
      'AgentStepResult(step: $step, succeeded: $succeeded)';
}

/// A multi-step agent execution plan.
///
/// Represents the full sequence of steps the agent intends to execute,
/// along with metadata about the plan's goal and current progress.
@immutable
class AgentPlan {
  /// Unique identifier for this plan.
  final String id;

  /// Human-readable goal description for this plan.
  final String goal;

  /// Ordered list of steps to execute.
  final List<AgentStep> steps;

  /// Index of the current step being executed (or next to execute).
  final int currentStepIndex;

  /// Results of already-executed steps.
  final List<AgentStepResult> stepResults;

  const AgentPlan({
    required this.id,
    required this.goal,
    required this.steps,
    this.currentStepIndex = 0,
    this.stepResults = const [],
  });

  /// Number of steps in the plan.
  int get totalSteps => steps.length;

  /// Steps that have been completed (index < currentStepIndex).
  List<AgentStep> get completedSteps =>
      steps.take(currentStepIndex).toList();

  /// Steps remaining to be executed.
  List<AgentStep> get remainingSteps =>
      steps.skip(currentStepIndex).toList();

  /// Whether all steps have been executed.
  bool get isComplete => currentStepIndex >= totalSteps;

  /// The current step (or null if plan is complete).
  AgentStep? get currentStep =>
      currentStepIndex < totalSteps ? steps[currentStepIndex] : null;

  /// Whether any step has failed.
  bool get hasFailedStep =>
      stepResults.any((r) => !r.succeeded);

  /// Number of successful steps.
  int get successfulStepCount =>
      stepResults.where((r) => r.succeeded).length;

  AgentPlan copyWith({
    String? id,
    String? goal,
    List<AgentStep>? steps,
    int? currentStepIndex,
    List<AgentStepResult>? stepResults,
  }) =>
      AgentPlan(
        id: id ?? this.id,
        goal: goal ?? this.goal,
        steps: steps ?? this.steps,
        currentStepIndex: currentStepIndex ?? this.currentStepIndex,
        stepResults: stepResults ?? this.stepResults,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentPlan &&
          id == other.id &&
          currentStepIndex == other.currentStepIndex;

  @override
  int get hashCode => Object.hash(id, currentStepIndex);

  @override
  String toString() =>
      'AgentPlan(id: $id, goal: $goal, steps: $totalSteps, current: $currentStepIndex)';
}
