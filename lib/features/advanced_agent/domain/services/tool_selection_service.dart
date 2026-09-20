/// tool_selection_service.dart
/// AURA Assistant – Step 25: Capability 5 — Tool Selection Intelligence
///
/// Abstract service interface for intelligent tool selection.
library;

import '../models/tool_selection_score.dart';

/// Service responsible for selecting the best tool for a given
/// action from a pool of candidates.
abstract class ToolSelectionService {
  /// Score and rank candidate tools for the given action.
  List<ToolSelectionScore> rankCandidates({
    required String action,
    required List<Map<String, dynamic>> candidates,
    required String locale,
  });

  /// Select the single best tool for the given action.
  /// Returns null if no suitable tool is found (fail-closed).
  ToolSelectionScore? selectBest({
    required String action,
    required List<Map<String, dynamic>> candidates,
    required String locale,
  });

  /// Whether the selected tool meets the minimum confidence threshold.
  bool meetsThreshold(ToolSelectionScore score);

  /// Minimum confidence threshold for tool selection.
  double get minConfidenceThreshold;
}
