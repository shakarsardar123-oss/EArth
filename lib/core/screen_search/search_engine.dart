/// Concrete implementation of [ScreenSearchService].
///
/// Searches an existing [ScreenRepresentation] for targets matching
/// a [SearchQuery]. Supports text search, UI element search,
/// semantic label search, and region search. Returns ranked results
/// with bounding boxes, confidence, and match reasons.
///
/// This is a read-only operation on [ScreenRepresentation] —
/// no new vision calls, no device actions.
library;

import 'dart:async';

import '../errors/failures.dart';
import '../errors/result.dart';
import '../screen_understanding/screen_understanding_result.dart';
import 'search_result.dart';
import 'search_service.dart';
import 'search_state.dart';

/// Concrete search engine that searches [ScreenRepresentation]
/// for targets matching a [SearchQuery].
class SearchEngine implements ScreenSearchService {
  SearchEngine();

  ScreenSearchState _state = const ScreenSearchState();
  final StreamController<ScreenSearchState> _stateController =
      StreamController<ScreenSearchState>.broadcast();
  bool _isCancelled = false;

  @override
  ScreenSearchState get state => _state;

  @override
  Stream<ScreenSearchState> get stateStream => _stateController.stream;

  @override
  Future<Result<SearchResults, ScreenSearchFailure>> search(
    SearchQuery query,
    ScreenRepresentation representation,
  ) async {
    _isCancelled = false;

    // Validate query
    if (query.query.isEmpty && query.uiElementTypeFilter == null && query.regionTypeFilter == null) {
      _updateState(_state.copyWith(
        status: ScreenSearchStatus.error,
        errorMessage: 'Search query cannot be empty with no filters',
      ));
      return const Result.failure(ScreenSearchFailure(
        message: 'Search query cannot be empty with no filters',
        phase: ScreenSearchPhase.queryParsing,
      ));
    }

    _updateState(_state.copyWith(
      status: ScreenSearchStatus.searching,
      results: null,
      errorMessage: null,
    ));

    final allResults = <SearchResult>[];

    try {
      switch (query.targetType) {
        case SearchTargetType.text:
          allResults.addAll(_searchText(query, representation));
        case SearchTargetType.uiElement:
          allResults.addAll(_searchUIElements(query, representation));
        case SearchTargetType.semantic:
          allResults.addAll(_searchSemantic(query, representation));
        case SearchTargetType.region:
          allResults.addAll(_searchRegions(query, representation));
      }

      // Filter out results whose computed confidence is below minConfidence.
      // This catches fuzzy/partial matches that passed the source-confidence
      // gate but whose final confidence (source × quality) is too low.
      allResults.removeWhere(
        (r) => r.confidence < query.minConfidence,
      );

      // Check cancellation after search
      if (_isCancelled) {
        _updateState(_state.copyWith(
          status: ScreenSearchStatus.cancelled,
        ));
        return const Result.failure(ScreenSearchFailure(
          message: 'Search was cancelled',
          phase: ScreenSearchPhase.cancelled,
        ));
      }

      // Rank results by confidence (descending)
      allResults.sort((a, b) => b.confidence.compareTo(a.confidence));

      // Apply maxResults truncation
      final truncated = allResults.length > query.maxResults;
      final cappedResults = truncated
          ? allResults.sublist(0, query.maxResults)
          : allResults;

      // Assign deterministic ranks
      final rankedResults = <SearchResult>[];
      for (var i = 0; i < cappedResults.length; i++) {
        rankedResults.add(cappedResults[i].copyWith(rank: i + 1));
      }

      final searchResults = SearchResults(
        query: query,
        results: rankedResults,
        isTruncated: truncated,
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      _updateState(_state.copyWith(
        status: rankedResults.isEmpty
            ? ScreenSearchStatus.noResults
            : ScreenSearchStatus.success,
        results: searchResults,
        searchCount: _state.searchCount + 1,
        lastSearchTimestamp: now,
      ));

      return Result.success(searchResults);
    } catch (e) {
      _updateState(_state.copyWith(
        status: ScreenSearchStatus.error,
        errorMessage: e.toString(),
      ));
      return Result.failure(ScreenSearchFailure(
        message: e.toString(),
        phase: ScreenSearchPhase.targetMatching,
      ));
    }
  }

  @override
  void cancel() {
    _isCancelled = true;
    _updateState(_state.copyWith(
      status: ScreenSearchStatus.cancelled,
    ));
  }

  @override
  Future<void> dispose() async {
    await _stateController.close();
  }

  // ── Private search implementations ─────────────────────────────

  /// Search for text items matching the query.
  List<SearchResult> _searchText(
    SearchQuery query,
    ScreenRepresentation representation,
  ) {
    final results = <SearchResult>[];
    final searchLower = query.query.toLowerCase();

    for (final textItem in representation.textItems) {
      if (textItem.confidence < query.minConfidence) continue;

      final textLower = textItem.text.toLowerCase();
      final isMatch = query.query.isEmpty ||
          textLower.contains(searchLower) ||
          _fuzzyMatch(searchLower, textLower);

      if (isMatch) {
        final matchQuality = _computeTextMatchQuality(
          query.query,
          textItem.text,
        );
        final confidence = textItem.confidence * matchQuality;

        results.add(SearchResult(
          targetType: SearchTargetType.text,
          boundingBox: textItem.boundingBox,
          confidence: confidence,
          matchReason: MatchReason.textMatch,
          rank: 0, // Will be assigned after sorting
          matchedText: textItem,
        ));
      }
    }

    return results;
  }

  /// Search for UI elements matching the query.
  List<SearchResult> _searchUIElements(
    SearchQuery query,
    ScreenRepresentation representation,
  ) {
    final results = <SearchResult>[];

    for (final element in representation.uiElements) {
      if (element.confidence < query.minConfidence) continue;

      // Filter by type if specified
      if (query.uiElementTypeFilter != null &&
          element.type != query.uiElementTypeFilter) {
        continue;
      }

      // Match by label if query is non-empty
      var labelMatch = false;
      var labelConfidence = 0.0;

      if (query.query.isNotEmpty && element.label != null) {
        final labelLower = element.label!.toLowerCase();
        final searchLower = query.query.toLowerCase();
        labelMatch = labelLower.contains(searchLower) ||
            _fuzzyMatch(searchLower, labelLower);
        if (labelMatch) {
          labelConfidence = _computeTextMatchQuality(
            query.query,
            element.label!,
          );
        }
      }

      // If type filter matches but no label query, it's a type match
      final isMatch = query.query.isEmpty
          ? query.uiElementTypeFilter != null
          : labelMatch;

      if (isMatch) {
        final confidence = element.confidence *
            (labelMatch ? labelConfidence : 1.0);

        results.add(SearchResult(
          targetType: SearchTargetType.uiElement,
          boundingBox: element.boundingBox,
          confidence: confidence,
          matchReason: labelMatch
              ? MatchReason.labelMatch
              : MatchReason.elementTypeMatch,
          rank: 0,
          matchedElement: element,
        ));
      }
    }

    return results;
  }

  /// Search by semantic / accessibility label.
  List<SearchResult> _searchSemantic(
    SearchQuery query,
    ScreenRepresentation representation,
  ) {
    final results = <SearchResult>[];
    final searchLower = query.query.toLowerCase();

    // Search UI element labels as semantic targets
    for (final element in representation.uiElements) {
      if (element.confidence < query.minConfidence) continue;
      if (element.label == null) continue;

      final labelLower = element.label!.toLowerCase();
      if (labelLower.contains(searchLower) ||
          _fuzzyMatch(searchLower, labelLower)) {
        final matchQuality = _computeTextMatchQuality(
          query.query,
          element.label!,
        );
        final confidence = element.confidence * matchQuality;

        results.add(SearchResult(
          targetType: SearchTargetType.semantic,
          boundingBox: element.boundingBox,
          confidence: confidence,
          matchReason: MatchReason.semanticLabelMatch,
          rank: 0,
          matchedElement: element,
        ));
      }
    }

    // Also search text items with button/heading/link types
    for (final textItem in representation.textItems) {
      if (textItem.confidence < query.minConfidence) continue;
      if (textItem.textType != TextType.button &&
          textItem.textType != TextType.heading &&
          textItem.textType != TextType.link &&
          textItem.textType != TextType.menuLabel) {
        continue;
      }

      final textLower = textItem.text.toLowerCase();
      if (textLower.contains(searchLower) ||
          _fuzzyMatch(searchLower, textLower)) {
        final matchQuality = _computeTextMatchQuality(
          query.query,
          textItem.text,
        );
        final confidence = textItem.confidence * matchQuality;

        results.add(SearchResult(
          targetType: SearchTargetType.semantic,
          boundingBox: textItem.boundingBox,
          confidence: confidence,
          matchReason: MatchReason.semanticLabelMatch,
          rank: 0,
          matchedText: textItem,
        ));
      }
    }

    return results;
  }

  /// Search for screen regions matching the query.
  List<SearchResult> _searchRegions(
    SearchQuery query,
    ScreenRepresentation representation,
  ) {
    final results = <SearchResult>[];

    for (final region in representation.regions) {
      if (region.confidence < query.minConfidence) continue;

      // Filter by type if specified
      if (query.regionTypeFilter != null &&
          region.type != query.regionTypeFilter) {
        continue;
      }

      // Match by type name if query is non-empty
      var nameMatch = false;
      if (query.query.isNotEmpty) {
        nameMatch = region.type.name.toLowerCase().contains(
              query.query.toLowerCase(),
            );
      }

      // If type filter matches but no name query, it's a type match
      final isMatch = query.query.isEmpty
          ? query.regionTypeFilter != null
          : nameMatch;

      if (isMatch) {
        results.add(SearchResult(
          targetType: SearchTargetType.region,
          boundingBox: region.boundingBox,
          confidence: region.confidence,
          matchReason: nameMatch
              ? MatchReason.regionTypeMatch
              : MatchReason.regionTypeMatch,
          rank: 0,
          matchedRegion: region,
        ));
      }
    }

    return results;
  }

  // ── Utility methods ────────────────────────────────────────────

  /// Simple fuzzy matching: allows up to 1 character transposition
  /// or 1 missing character. Returns true if the strings are
  /// "close enough" to be considered a match.
  bool _fuzzyMatch(String query, String target) {
    if (query.isEmpty) return true;
    if (query.length <= 2) return false; // Too short for fuzzy

    // Check for single-character transposition
    final transposed = _transpose(query);
    if (target.contains(transposed)) return true;

    // Check for single-character deletion from query
    // (handles extra character in query, e.g. 'Logni' → 'Logi' contained in 'Login')
    for (var i = 0; i < query.length; i++) {
      final deleted = query.substring(0, i) + query.substring(i + 1);
      if (target.contains(deleted)) return true;
    }

    // Check for single-character insertion (missing character in query)
    // (handles missing character, e.g. 'Setings' is contained in 'Settings' with 't' removed)
    if (query.length < target.length) {
      for (var i = 0; i < target.length; i++) {
        final deleted = target.substring(0, i) + target.substring(i + 1);
        if (deleted.contains(query)) return true;
      }
    }

    return false;
  }

  /// Transpose adjacent characters (swap each pair) to handle
  /// common typos.
  String _transpose(String s) {
    if (s.length < 2) return s;
    // Swap first two characters as a simple transposition
    return s[1] + s[0] + s.substring(2);
  }

  /// Compute match quality (0.0–1.0) between query and target text.
  ///
  /// - Exact match: 1.0
  /// - Case-insensitive exact: 0.95
  /// - Contains match (substring): 0.8
  /// - Starts-with: 0.75
  /// - Fuzzy match: 0.6
  double _computeTextMatchQuality(String query, String target) {
    if (query.isEmpty) return 1.0;

    // Exact match
    if (query == target) return 1.0;

    // Case-insensitive exact
    if (query.toLowerCase() == target.toLowerCase()) return 0.95;

    // Starts-with
    final targetLower = target.toLowerCase();
    final queryLower = query.toLowerCase();
    if (targetLower.startsWith(queryLower)) return 0.75;

    // Contains (substring)
    if (targetLower.contains(queryLower)) return 0.8;

    // Fuzzy
    if (_fuzzyMatch(queryLower, targetLower)) return 0.6;

    // No match
    return 0.0;
  }

  /// Update state and notify listeners.
  void _updateState(ScreenSearchState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }
}

/// Extension on [SearchResult] to support copyWith for rank assignment.
extension SearchResultCopyWith on SearchResult {
  /// Create a copy of this [SearchResult] with an updated rank.
  SearchResult copyWith({int? rank}) {
    return SearchResult(
      targetType: targetType,
      boundingBox: boundingBox,
      confidence: confidence,
      matchReason: matchReason,
      rank: rank ?? this.rank,
      matchedText: matchedText,
      matchedElement: matchedElement,
      matchedRegion: matchedRegion,
    );
  }
}
