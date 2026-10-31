/// task_dependency.dart
/// AURA Assistant – Step 25: Advanced Agent Capabilities
///
/// Dependency relationship between two steps in a task plan.
library;

/// The type of dependency between two task steps.
enum DependencyType {
  /// The dependent step cannot start until the source step completes.
  finishToStart,

  /// The dependent step cannot start until the source step starts.
  startToStart,

  /// The source step cannot finish until the dependent step finishes.
  finishToFinish,

  /// The source step cannot finish until the dependent step starts.
  startToFinish,
  ;

  /// FAIL-CLOSED: any unknown name maps to [finishToStart] (most restrictive).
  static DependencyType fromName(String name) {
    return DependencyType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => DependencyType.finishToStart,
    );
  }
}

/// A single dependency edge in the task plan DAG.
///
/// [sourceStepId] must complete/start before [dependentStepId] can proceed.
class TaskDependency {
  final String sourceStepId;
  final String dependentStepId;
  final DependencyType type;

  const TaskDependency({
    required this.sourceStepId,
    required this.dependentStepId,
    this.type = DependencyType.finishToStart,
  });

  TaskDependency copyWith({
    String? sourceStepId,
    String? dependentStepId,
    DependencyType? type,
  }) =>
      TaskDependency(
        sourceStepId: sourceStepId ?? this.sourceStepId,
        dependentStepId: dependentStepId ?? this.dependentStepId,
        type: type ?? this.type,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskDependency &&
          sourceStepId == other.sourceStepId &&
          dependentStepId == other.dependentStepId &&
          type == other.type;

  @override
  int get hashCode => Object.hash(sourceStepId, dependentStepId, type);

  @override
  String toString() =>
      'TaskDependency($sourceStepId -> $dependentStepId, type: $type)';
}
