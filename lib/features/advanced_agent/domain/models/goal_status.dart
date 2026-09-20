/// goal_status.dart
/// AURA Assistant – Step 25: Advanced Agent Capabilities
///
/// Status enum for agent goals (capability 3: Goal Tracking).
/// FAIL-CLOSED: unknown status defaults to [failed].
library;

/// The status of an agent goal being tracked.
enum GoalStatus {
  /// Goal is defined but not yet started.
  defined,

  /// Goal is actively being pursued.
  inProgress,

  /// Goal has been achieved.
  achieved,

  /// Goal could not be achieved.
  failed,

  /// Goal was abandoned (user or system decision).
  abandoned,

  /// Goal is paused, pending external input or resolution.
  paused,
  ;

  /// Whether this is a terminal goal status.
  bool get isTerminal =>
      this == GoalStatus.achieved ||
      this == GoalStatus.failed ||
      this == GoalStatus.abandoned;

  /// Whether the goal is actively being worked on.
  bool get isActive => !isTerminal;

  /// FAIL-CLOSED: any unknown name maps to [failed].
  static GoalStatus fromName(String name) {
    return GoalStatus.values.firstWhere(
      (e) => e.name == name,
      orElse: () => GoalStatus.failed,
    );
  }
}
