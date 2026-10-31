/// tool_selection_score.dart
/// AURA Assistant – Step 25: Advanced Agent Capabilities
///
/// Score for a candidate tool during tool selection (capability 5).
/// Higher score = better match for the current request.
library;

/// A scored candidate tool for intelligent tool selection.
class ToolSelectionScore {
  final String toolId;
  final double relevanceScore;
  final double capabilityScore;
  final double reliabilityScore;
  final double compositeScore;
  final String rationale;
  final String locale;

  const ToolSelectionScore({
    required this.toolId,
    this.relevanceScore = 0.0,
    this.capabilityScore = 0.0,
    this.reliabilityScore = 0.0,
    this.compositeScore = 0.0,
    this.rationale = '',
    this.locale = 'ku',
  });

  /// Whether this score meets a minimum threshold for selection.
  bool meetsThreshold({double threshold = 0.5}) =>
      compositeScore >= threshold;

  /// Compare scores by composite (descending).
  int compareTo(ToolSelectionScore other) =>
      other.compositeScore.compareTo(compositeScore);

  ToolSelectionScore copyWith({
    String? toolId,
    double? relevanceScore,
    double? capabilityScore,
    double? reliabilityScore,
    double? compositeScore,
    String? rationale,
    String? locale,
  }) =>
      ToolSelectionScore(
        toolId: toolId ?? this.toolId,
        relevanceScore: relevanceScore ?? this.relevanceScore,
        capabilityScore: capabilityScore ?? this.capabilityScore,
        reliabilityScore: reliabilityScore ?? this.reliabilityScore,
        compositeScore: compositeScore ?? this.compositeScore,
        rationale: rationale ?? this.rationale,
        locale: locale ?? this.locale,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolSelectionScore &&
          toolId == other.toolId &&
          compositeScore == other.compositeScore;

  @override
  int get hashCode => Object.hash(toolId, compositeScore);

  @override
  String toString() =>
      'ToolSelectionScore(tool: $toolId, composite: $compositeScore, '
      'rationale: $rationale)';
}
