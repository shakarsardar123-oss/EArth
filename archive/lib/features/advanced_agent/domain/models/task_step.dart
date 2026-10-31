/// task_step.dart
/// AURA Assistant – Step 25: Advanced Agent Capabilities
///
/// A single step within a multi-step task plan.
/// Immutable; transitions return new instances via [copyWith].
library;

import 'task_step_status.dart';

/// A single executable step within a [AdvancedTaskPlan].
///
/// Each step has a unique ID, description, optional tool binding,
/// status, and retry metadata. Steps are connected via
/// [TaskDependency] edges in the parent plan.
class TaskStep {
  final String stepId;
  final String description;
  final int order;
  final String? toolId;
  final String? action;
  final Map<String, dynamic> parameters;
  final TaskStepStatus status;
  final int retryAttempt;
  final int maxRetries;
  final String? errorMessage;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String locale;

  const TaskStep({
    required this.stepId,
    required this.description,
    required this.order,
    this.toolId,
    this.action,
    this.parameters = const {},
    this.status = TaskStepStatus.pending,
    this.retryAttempt = 0,
    this.maxRetries = 3,
    this.errorMessage,
    this.startedAt,
    this.completedAt,
    this.locale = 'ku',
  });

  /// Whether this step can be retried.
  bool get canRetry =>
      status.canRetry && retryAttempt < maxRetries;

  /// Whether this step requires a tool to execute.
  bool get requiresTool => toolId != null && toolId!.isNotEmpty;

  /// Whether this step has completed successfully.
  bool get isCompleted => status == TaskStepStatus.completed;

  /// Whether this step has failed.
  bool get isFailed => status == TaskStepStatus.failed;

  /// Whether this step is paused.
  bool get isPaused => status == TaskStepStatus.paused;

  /// Duration of execution if both timestamps are available.
  Duration? get executionDuration {
    if (startedAt != null && completedAt != null) {
      return completedAt!.difference(startedAt!);
    }
    return null;
  }

  TaskStep copyWith({
    String? stepId,
    String? description,
    int? order,
    String? toolId,
    String? action,
    Map<String, dynamic>? parameters,
    TaskStepStatus? status,
    int? retryAttempt,
    int? maxRetries,
    String? errorMessage,
    DateTime? startedAt,
    DateTime? completedAt,
    String? locale,
  }) =>
      TaskStep(
        stepId: stepId ?? this.stepId,
        description: description ?? this.description,
        order: order ?? this.order,
        toolId: toolId ?? this.toolId,
        action: action ?? this.action,
        parameters: parameters ?? this.parameters,
        status: status ?? this.status,
        retryAttempt: retryAttempt ?? this.retryAttempt,
        maxRetries: maxRetries ?? this.maxRetries,
        errorMessage: errorMessage ?? this.errorMessage,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        locale: locale ?? this.locale,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskStep &&
          stepId == other.stepId &&
          description == other.description &&
          order == other.order &&
          toolId == other.toolId &&
          action == other.action &&
          status == other.status &&
          retryAttempt == other.retryAttempt;

  @override
  int get hashCode =>
      Object.hash(stepId, description, order, toolId, action, status, retryAttempt);

  @override
  String toString() =>
      'TaskStep(id: $stepId, order: $order, status: $status, '
      'tool: $toolId, retry: $retryAttempt/$maxRetries)';
}
