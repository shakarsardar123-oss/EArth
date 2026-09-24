/// Result models for the AURA screen-search / target-detection subsystem.
///
/// [SearchQuery] describes what to look for, and [SearchResult]
/// represents a single ranked match within a [ScreenRepresentation].
library;

import 'package:meta/meta.dart' show immutable;

import '../screen_understanding/screen_understanding_result.dart';

// ── Enums ────────────────────────────────────────────────────────

/// The type of target the search is looking for.
enum SearchTargetType {
  /// Search for visible text (content matching).
  text,

  /// Search for a specific UI element type (button, field, etc.).
  uiElement,

  /// Search by semantic / accessibility label.
  semantic,

  /// Search within a named screen region.
  region,
}

// ── Search Query ────────────────────────────────────────────────

/// A structured query describing what to search for on the screen.
@immutable
class SearchQuery {
  const SearchQuery({
    required this.targetType,
    required this.query,
    this.uiElementTypeFilter,
    this.regionTypeFilter,
    this.minConfidence = 0.0,
    this.maxResults = 50,
  });

  /// What type of target to search for.
  final SearchTargetType targetType;

  /// The search string / label / type name.
  ///
  /// For [SearchTargetType.text] and [SearchTargetType.semantic],
  /// this is the text or label to match.
  /// For [SearchTargetType.uiElement], this can be an element label
  /// or left empty if [uiElementTypeFilter] is used instead.
  /// For [SearchTargetType.region], this can be a region name
  /// or left empty if [regionTypeFilter] is used.
  final String query;

  /// Optional filter: only match UI elements of this type.
  final UIElementType? uiElementTypeFilter;

  /// Optional filter: only match regions of this type.
  final ScreenRegionType? regionTypeFilter;

  /// Minimum confidence threshold for matches (0.0–1.0).
  final double minConfidence;

  /// Maximum number of results to return.
  final int maxResults;

  /// Whether the text/label match should be case-insensitive.
  bool get isTextSearch =>
      targetType == SearchTargetType.text ||
      targetType == SearchTargetType.semantic;

  @override
  String toString() =>
      'SearchQuery(type: ${targetType.name}, query: "$query", '
      'minConf: $minConfidence, max: $maxResults)';
}

// ── Search Result ───────────────────────────────────────────────

/// The reason a target matched the query.
enum MatchReason {
  /// Text content matched the query (exact or fuzzy).
  textMatch,

  /// UI element type matched the filter.
  elementTypeMatch,

  /// Accessibility / semantic label matched.
  semanticLabelMatch,

  /// Region type matched the filter.
  regionTypeMatch,

  /// The target's label matched the query.
  labelMatch,
}

/// A single ranked search result — one target that matched a query.
@immutable
class SearchResult {
  const SearchResult({
    required this.targetType,
    required this.boundingBox,
    required this.confidence,
    required this.matchReason,
    required this.rank,
    this.matchedText,
    this.matchedElement,
    this.matchedRegion,
  });

  /// What kind of target was matched.
  final SearchTargetType targetType;

  /// Bounding box of the matched target (normalized 0.0–1.0).
  final TextBoundingBox boundingBox;

  /// Overall confidence that this result is correct (0.0–1.0).
  /// Combines the source detection confidence with match quality.
  final double confidence;

  /// Why this target matched the query.
  final MatchReason matchReason;

  /// Ranking position (1 = best match).
  final int rank;

  /// The matched text, if [targetType] is text or semantic.
  final ScreenTextItem? matchedText;

  /// The matched UI element, if [targetType] is uiElement.
  final UIElement? matchedElement;

  /// The matched region, if [targetType] is region.
  final ScreenRegion? matchedRegion;

  /// Whether this result is ambiguous (low confidence or weak match).
  bool get isAmbiguous => confidence < 0.5;

  @override
  String toString() =>
      'SearchResult(rank: $rank, type: ${targetType.name}, '
      'conf: ${confidence.toStringAsFixed(2)}, '
      'reason: ${matchReason.name})';
}

/// A complete set of search results for a single query.
@immutable
class SearchResults {
  const SearchResults({
    required this.query,
    required this.results,
    this.isTruncated = false,
  });

  /// The query that produced these results.
  final SearchQuery query;

  /// Ranked search results, ordered by confidence (highest first).
  final List<SearchResult> results;

  /// Whether results were truncated due to [SearchQuery.maxResults].
  final bool isTruncated;

  /// Number of results.
  int get count => results.length;

  /// Whether any results were found.
  bool get hasResults => results.isNotEmpty;

  /// Whether there are ambiguous results (confidence < 0.5).
  bool get hasAmbiguousResults => results.any((r) => r.isAmbiguous);

  /// The best (top-ranked) result, or null if empty.
  SearchResult? get best =>
      results.isEmpty ? null : results.first;

  /// All results with confidence >= 0.5 (non-ambiguous).
  List<SearchResult> get confidentResults =>
      results.where((r) => !r.isAmbiguous).toList();

  @override
  String toString() =>
      'SearchResults(count: $count, truncated: $isTruncated, '
      'ambiguous: $hasAmbiguousResults)';
}
