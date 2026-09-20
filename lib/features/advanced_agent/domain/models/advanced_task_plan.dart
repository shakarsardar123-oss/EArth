/// advanced_task_plan.dart
/// AURA Assistant – Step 25: Advanced Agent Capabilities
///
/// Multi-step task plan model — the core data structure for
/// capability (1) Multi-Step Task Planning.
/// Immutable; transitions return new instances via [copyWith].
library;

import 'task_step.dart';
import 'task_step_status.dart';
import 'task_dependency.dart';

/// Status of the overall task plan.
enum PlanStatus {
  draft,
  active,
  completed,
  failed,
  cancelled,
  paused,
  ;

  /// Whether this status represents a terminal state.
  bool get isTerminal =>
      this == PlanStatus.completed ||
      this == PlanStatus.failed ||
      this == PlanStatus.cancelled;

  /// FAIL-CLOSED: any unknown name maps to [failed].
  static PlanStatus fromName(String name) {
    return PlanStatus.values.firstWhere(
      (e) => e.name == name,
      orElse: () => PlanStatus.failed,
    );
  }
}

/// A multi-step task plan produced by the TaskPlannerService.
///
/// Contains ordered [TaskStep]s with optional dependency edges,
/// and tracks overall progress. This is the primary data structure
/// for capability (1) Multi-Step Task Planning.
class AdvancedTaskPlan {
  final String planId;
  final String intentId;
  final String rawRequest;
  final List<TaskStep> steps;
  final List<TaskDependency> dependencies;
  final PlanStatus status;
  final String locale;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int version;

  const AdvancedTaskPlan({
    required this.planId,
    required this.intentId,
    required this.rawRequest,
    this.steps = const [],
    this.dependencies = const [],
    this.status = PlanStatus.draft,
    this.locale = 'ku',
    required this.createdAt,
    this.updatedAt,
    this.version = 1,
  });

  // ─── Computed properties ─────────────────────────────────────────

  /// Number of completed steps.
  int get completedSteps =>
      steps.where((s) => s.isCompleted).length;

  /// Number of failed steps.
  int get failedSteps =>
      steps.where((s) => s.isFailed).length;

  /// Number of currently in-progress steps.
  int get inProgressSteps =>
      steps.where((s) => s.status == TaskStepStatus.inProgress).length;

  /// Number of paused steps.
  int get pausedSteps =>
      steps.where((s) => s.isPaused).length;

  /// Overall progress as a fraction 0.0..1.0.
  double get progress =>
      steps.isEmpty ? 0.0 : completedSteps / steps.length;

  /// Whether all steps are terminal (completed, failed, skipped, or cancelled).
  bool get allStepsTerminal =>
      steps.every((s) => s.status.isTerminal);

  /// Whether the plan has any failed steps that can be retried.
  bool get hasRetryableSteps =>
      steps.any((s) => s.canRetry);

  /// Steps ordered by their [TaskStep.order].
  List<TaskStep> get orderedSteps =>
      List.of(steps)..sort((a, b) => a.order.compareTo(b.order));

  /// The current active step (first non-terminal step by order), or null.
  TaskStep? get currentStep {
    final ordered = orderedSteps;
    for (final step in ordered) {
      if (step.status.isActive) return step;
    }
    return null;
  }

  /// The next step after [currentStep] that is still pending, or null.
  TaskStep? get nextPendingStep {
    final ordered = orderedSteps;
    for (final step in ordered) {
      if (step.status == TaskStepStatus.pending) return step;
    }
    return null;
  }

  /// Find a step by ID.
  TaskStep? stepById(String stepId) {
    try {
      return steps.firstWhere((s) => s.stepId == stepId);
    } catch (_) {
      return null;
    }
  }

  /// Get all dependency source step IDs for a given step.
  Set<String> dependenciesOf(String stepId) => dependencies
      .where((d) => d.dependentStepId == stepId)
      .map((d) => d.sourceStepId)
      .toSet();

  /// Whether all dependencies of [stepId] are satisfied (completed or skipped).
  bool areDependenciesSatisfied(String stepId, {TaskStep? step}) {
    final depSourceIds = dependenciesOf(stepId);
    if (depSourceIds.isEmpty) return true;
    return depSourceIds.every((sourceId) {
      final source = stepById(sourceId);
      if (source == null) return false; // FAIL-CLOSED: missing dep = not satisfied
      return source.isCompleted ||
          source.status == TaskStepStatus.skipped;
    });
  }

  // ─── Factory constructors ────────────────────────────────────────

  /// Create a new plan in draft status.
  factory AdvancedTaskPlan.create({
    required String planId,
    required String intentId,
    required String rawRequest,
    required List<TaskStep> steps,
    List<TaskDependency> dependencies = const [],
    String locale = 'ku',
  }) =>
      AdvancedTaskPlan(
        planId: planId,
        intentId: intentId,
        rawRequest: rawRequest,
        steps: steps,
        dependencies: dependencies,
        status: PlanStatus.draft,
        locale: locale,
        createdAt: DateTime.now(),
      );

  /// FAIL-CLOSED: create a failed plan.
  factory AdvancedTaskPlan.failed({
    required String planId,
    required String intentId,
    required String rawRequest,
    required String errorMessage,
    String locale = 'ku',
  }) {
    final failedStep = TaskStep(
      stepId: '${planId}_error',
      description: errorMessage,
      order: 0,
      status: TaskStepStatus.failed,
      errorMessage: errorMessage,
      locale: locale,
    );
    return AdvancedTaskPlan(
      planId: planId,
      intentId: intentId,
      rawRequest: rawRequest,
      steps: [failedStep],
      status: PlanStatus.failed,
      locale: locale,
      createdAt: DateTime.now(),
    );
  }

  // ─── copyWith ───────────────────────────────────────────────────

  AdvancedTaskPlan copyWith({
    String? planId,
    String? intentId,
    String? rawRequest,
    List<TaskStep>? steps,
    List<TaskDependency>? dependencies,
    PlanStatus? status,
    String? locale,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) =>
      AdvancedTaskPlan(
        planId: planId ?? this.planId,
        intentId: intentId ?? this.intentId,
        rawRequest: rawRequest ?? this.rawRequest,
        steps: steps ?? this.steps,
        dependencies: dependencies ?? this.dependencies,
        status: status ?? this.status,
        locale: locale ?? this.locale,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        version: version ?? this.version,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdvancedTaskPlan &&
          planId == other.planId &&
          intentId == other.intentId &&
          version == other.version;

  @override
  int get hashCode => Object.hash(planId, intentId, version);

  @override
  String toString() =>
      'AdvancedTaskPlan(id: $planId, status: $status, '
      'steps: ${steps.length}, progress: ${(progress * 100).toStringAsFixed(0)}%)';
}
