/// agent_goal.dart
/// AURA Assistant – Step 25: Advanced Agent Capabilities
///
/// A tracked goal within the agent's execution lifecycle (capability 3).
/// Immutable; transitions return new instances via [copyWith].
library;

import 'goal_status.dart';
import 'goal_progress.dart';

/// A goal being tracked by the agent during task execution.
///
/// Goals provide high-level direction for task plans.
/// Multiple steps may contribute to a single goal.
class AgentGoal {
  final String goalId;
  final String description;
  final GoalStatus status;
  final GoalProgress progress;
  final String? parentGoalId;
  final String locale;
  final DateTime createdAt;
  final DateTime? achievedAt;

  const AgentGoal({
    required this.goalId,
    required this.description,
    this.status = GoalStatus.defined,
    this.progress = const GoalProgress(updatedAt: null),
    this.parentGoalId,
    this.locale = 'ku',
    required this.createdAt,
    this.achievedAt,
  });

  /// Whether the goal has been achieved.
  bool get isAchieved => status == GoalStatus.achieved;

  /// Whether the goal has failed.
  bool get isFailed => status == GoalStatus.failed;

  /// Whether the goal is a sub-goal (has a parent).
  bool get isSubGoal => parentGoalId != null;

  /// Create a new goal in defined status.
  factory AgentGoal.define({
    required String goalId,
    required String description,
    String? parentGoalId,
    String locale = 'ku',
  }) =>
      AgentGoal(
        goalId: goalId,
        description: description,
        status: GoalStatus.defined,
        progress: GoalProgress(updatedAt: DateTime.now()),
        parentGoalId: parentGoalId,
        locale: locale,
        createdAt: DateTime.now(),
      );

  /// FAIL-CLOSED: create a failed goal.
  factory AgentGoal.failed({
    required String goalId,
    required String description,
    String? parentGoalId,
    String locale = 'ku',
  }) =>
      AgentGoal(
        goalId: goalId,
        description: description,
        status: GoalStatus.failed,
        progress: GoalProgress(updatedAt: DateTime.now()),
        parentGoalId: parentGoalId,
        locale: locale,
        createdAt: DateTime.now(),
      );

  AgentGoal copyWith({
    String? goalId,
    String? description,
    GoalStatus? status,
    GoalProgress? progress,
    String? parentGoalId,
    String? locale,
    DateTime? createdAt,
    DateTime? achievedAt,
  }) =>
      AgentGoal(
        goalId: goalId ?? this.goalId,
        description: description ?? this.description,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        parentGoalId: parentGoalId ?? this.parentGoalId,
        locale: locale ?? this.locale,
        createdAt: createdAt ?? this.createdAt,
        achievedAt: achievedAt ?? this.achievedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentGoal && goalId == other.goalId;

  @override
  int get hashCode => goalId.hashCode;

  @override
  String toString() =>
      'AgentGoal(id: $goalId, status: $status, progress: ${progress.percentage}%)';
}
