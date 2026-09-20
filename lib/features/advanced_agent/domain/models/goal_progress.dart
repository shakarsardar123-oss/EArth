/// goal_progress.dart
/// AURA Assistant – Step 25: Advanced Agent Capabilities
///
/// Quantitative progress for a tracked goal.
library;

class GoalProgress {
  /// Fraction of goal completed, 0.0 to 1.0.
  final double fraction;

  /// Human-readable description of current progress.
  final String description;

  /// Number of sub-goals or steps completed.
  final int completedCount;

  /// Total number of sub-goals or steps.
  final int totalCount;

  /// Timestamp of last progress update.
  final DateTime updatedAt;

  const GoalProgress({
    this.fraction = 0.0,
    this.description = '',
    this.completedCount = 0,
    this.totalCount = 0,
    required this.updatedAt,
  });

  /// Whether the goal is fully complete.
  bool get isComplete => fraction >= 1.0;

  /// Percentage representation (0–100).
  int get percentage => (fraction * 100).round().clamp(0, 100);

  GoalProgress copyWith({
    double? fraction,
    String? description,
    int? completedCount,
    int? totalCount,
    DateTime? updatedAt,
  }) =>
      GoalProgress(
        fraction: fraction ?? this.fraction,
        description: description ?? this.description,
        completedCount: completedCount ?? this.completedCount,
        totalCount: totalCount ?? this.totalCount,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalProgress &&
          fraction == other.fraction &&
          completedCount == other.completedCount &&
          totalCount == other.totalCount;

  @override
  int get hashCode => Object.hash(fraction, completedCount, totalCount);

  @override
  String toString() =>
      'GoalProgress($percentage%, $completedCount/$totalCount, $description)';
}
