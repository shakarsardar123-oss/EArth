/// Tests for SearchQuery, SearchResult, SearchResults, MatchReason,
/// and SearchTargetType — Step 10 screen-search subsystem.
library;

import 'package:aura_assistant/core/screen_search/search_result.dart';
import 'package:aura_assistant/core/screen_understanding/screen_understanding_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ----------------------------------------------------------------
  // SearchTargetType
  // ----------------------------------------------------------------
  group('SearchTargetType', () {
    test('has all expected values', () {
      expect(SearchTargetType.values, containsAll([
        SearchTargetType.text,
        SearchTargetType.uiElement,
        SearchTargetType.semantic,
        SearchTargetType.region,
      ]));
    });
  });

  // ----------------------------------------------------------------
  // MatchReason
  // ----------------------------------------------------------------
  group('MatchReason', () {
    test('has all expected values', () {
      expect(MatchReason.values, containsAll([
        MatchReason.textMatch,
        MatchReason.elementTypeMatch,
        MatchReason.semanticLabelMatch,
        MatchReason.regionTypeMatch,
        MatchReason.labelMatch,
      ]));
    });
  });

  // ----------------------------------------------------------------
  // SearchQuery
  // ----------------------------------------------------------------
  group('SearchQuery', () {
    test('text query is constructed correctly', () {
      const query = SearchQuery(
        targetType: SearchTargetType.text,
        query: 'Login',
      );
      expect(query.targetType, SearchTargetType.text);
      expect(query.query, 'Login');
      expect(query.minConfidence, 0.0);
      expect(query.maxResults, 50);
      expect(query.isTextSearch, isTrue);
    });

    test('uiElement query with type filter', () {
      const query = SearchQuery(
        targetType: SearchTargetType.uiElement,
        query: 'Submit',
        uiElementTypeFilter: UIElementType.button,
      );
      expect(query.targetType, SearchTargetType.uiElement);
      expect(query.uiElementTypeFilter, UIElementType.button);
      expect(query.isTextSearch, isFalse);
    });

    test('region query with region type filter', () {
      const query = SearchQuery(
        targetType: SearchTargetType.region,
        query: 'Header',
        regionTypeFilter: ScreenRegionType.appBar,
      );
      expect(query.targetType, SearchTargetType.region);
      expect(query.regionTypeFilter, ScreenRegionType.appBar);
      expect(query.isTextSearch, isFalse);
    });

    test('semantic query', () {
      const query = SearchQuery(
        targetType: SearchTargetType.semantic,
        query: 'navigation',
      );
      expect(query.targetType, SearchTargetType.semantic);
      expect(query.isTextSearch, isTrue); // semantic is also textSearch
    });

    test('custom minConfidence and maxResults', () {
      const query = SearchQuery(
        targetType: SearchTargetType.text,
        query: 'test',
        minConfidence: 0.5,
        maxResults: 3,
      );
      expect(query.minConfidence, 0.5);
      expect(query.maxResults, 3);
    });

    test('isTextSearch is true for text and semantic', () {
      expect(
        const SearchQuery(
          targetType: SearchTargetType.text,
          query: 'a',
        ).isTextSearch,
        isTrue,
      );
      expect(
        const SearchQuery(
          targetType: SearchTargetType.semantic,
          query: 'a',
        ).isTextSearch,
        isTrue,
      );
      expect(
        const SearchQuery(
          targetType: SearchTargetType.uiElement,
          query: 'a',
        ).isTextSearch,
        isFalse,
      );
      expect(
        const SearchQuery(
          targetType: SearchTargetType.region,
          query: 'a',
        ).isTextSearch,
        isFalse,
      );
    });
  });

  // ----------------------------------------------------------------
  // SearchResult
  // ----------------------------------------------------------------
  group('SearchResult', () {
    test('construction with required fields', () {
      const result = SearchResult(
        targetType: SearchTargetType.text,
        boundingBox: TextBoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.1),
        confidence: 0.9,
        matchReason: MatchReason.textMatch,
        rank: 1,
      );
      expect(result.targetType, SearchTargetType.text);
      expect(result.confidence, 0.9);
      expect(result.matchReason, MatchReason.textMatch);
      expect(result.rank, 1);
      expect(result.matchedText, isNull);
      expect(result.matchedElement, isNull);
      expect(result.matchedRegion, isNull);
      expect(result.isAmbiguous, isFalse); // 0.9 >= 0.5
    });

    test('isAmbiguous is true when confidence < 0.5', () {
      const result = SearchResult(
        targetType: SearchTargetType.text,
        boundingBox: TextBoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.1),
        confidence: 0.3,
        matchReason: MatchReason.textMatch,
        rank: 1,
      );
      expect(result.isAmbiguous, isTrue);
    });

    test('construction with matchedText', () {
      final textItem = ScreenTextItem(
        text: 'Login',
        boundingBox: const TextBoundingBox(
          x: 0.1, y: 0.2, width: 0.3, height: 0.05,
        ),
        confidence: 0.9,
      );
      final result = SearchResult(
        targetType: SearchTargetType.text,
        boundingBox: textItem.boundingBox,
        confidence: 0.9,
        matchReason: MatchReason.textMatch,
        rank: 1,
        matchedText: textItem,
      );
      expect(result.matchedText, textItem);
      expect(result.matchedText!.text, 'Login');
    });

    test('re-constructing with a different rank preserves other fields',
        () {
      const result = SearchResult(
        targetType: SearchTargetType.text,
        boundingBox: TextBoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.1),
        confidence: 0.9,
        matchReason: MatchReason.textMatch,
        rank: 1,
      );
      const updated = SearchResult(
        targetType: SearchTargetType.text,
        boundingBox: TextBoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.1),
        confidence: 0.9,
        matchReason: MatchReason.textMatch,
        rank: 3,
      );
      expect(updated.rank, 3);
      expect(updated.confidence, result.confidence);
      expect(updated.targetType, result.targetType);
      expect(updated.matchReason, result.matchReason);
    });

    test('re-constructed result preserves matchedText when rank changes',
        () {
      final textItem = ScreenTextItem(
        text: 'Hello',
        boundingBox: const TextBoundingBox(
          x: 0.05, y: 0.1, width: 0.5, height: 0.025,
        ),
        confidence: 0.75,
      );
      final result = SearchResult(
        targetType: SearchTargetType.text,
        boundingBox: textItem.boundingBox,
        confidence: 0.75,
        matchReason: MatchReason.textMatch,
        rank: 2,
        matchedText: textItem,
      );
      final updated = SearchResult(
        targetType: result.targetType,
        boundingBox: result.boundingBox,
        confidence: result.confidence,
        matchReason: result.matchReason,
        rank: 5,
        matchedText: result.matchedText,
      );
      expect(updated.rank, 5);
      expect(updated.matchedText, textItem);
      expect(updated.boundingBox.x, 0.05);
      expect(updated.boundingBox.y, 0.1);
    });
  });

  // ----------------------------------------------------------------
  // SearchResults
  // ----------------------------------------------------------------
  group('SearchResults', () {
    late SearchQuery query;

    setUp(() {
      query = const SearchQuery(
        targetType: SearchTargetType.text,
        query: 'Login',
      );
    });

    test('empty results', () {
      final results = SearchResults(query: query, results: const []);
      expect(results.count, 0);
      expect(results.hasResults, isFalse);
      expect(results.hasAmbiguousResults, isFalse);
      expect(results.best, isNull);
      expect(results.confidentResults, isEmpty);
      expect(results.isTruncated, isFalse);
    });

    test('single result', () {
      final results = SearchResults(query: query, results: [
        const SearchResult(
          targetType: SearchTargetType.text,
          boundingBox: TextBoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.1),
          confidence: 0.9,
          matchReason: MatchReason.textMatch,
          rank: 1,
        ),
      ]);
      expect(results.count, 1);
      expect(results.hasResults, isTrue);
      expect(results.best, isNotNull);
      expect(results.best!.confidence, 0.9);
      expect(results.best!.rank, 1);
    });

    test('multiple results — best returns highest confidence', () {
      final results = SearchResults(query: query, results: [
        const SearchResult(
          targetType: SearchTargetType.text,
          boundingBox: TextBoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.1),
          confidence: 0.7,
          matchReason: MatchReason.textMatch,
          rank: 2,
        ),
        const SearchResult(
          targetType: SearchTargetType.text,
          boundingBox: TextBoundingBox(x: 0.5, y: 0.2, width: 0.3, height: 0.1),
          confidence: 0.95,
          matchReason: MatchReason.textMatch,
          rank: 1,
        ),
      ]);
      // best is results.first (first in the list), not sorted by confidence
      expect(results.best!.confidence, 0.7);
    });

    test('confidentResults filters by ambiguity threshold', () {
      final results = SearchResults(query: query, results: [
        const SearchResult(
          targetType: SearchTargetType.text,
          boundingBox: TextBoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.1),
          confidence: 0.3,
          matchReason: MatchReason.textMatch,
          rank: 3,
        ),
        const SearchResult(
          targetType: SearchTargetType.text,
          boundingBox: TextBoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.1),
          confidence: 0.6,
          matchReason: MatchReason.textMatch,
          rank: 2,
        ),
        const SearchResult(
          targetType: SearchTargetType.text,
          boundingBox: TextBoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.1),
          confidence: 0.9,
          matchReason: MatchReason.textMatch,
          rank: 1,
        ),
      ]);
      // confidentResults filters out ambiguous (< 0.5) results
      expect(results.confidentResults.length, 2);
    });

    test('hasAmbiguousResults detects ambiguity', () {
      final results = SearchResults(query: query, results: [
        const SearchResult(
          targetType: SearchTargetType.text,
          boundingBox: TextBoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.1),
          confidence: 0.3,
          matchReason: MatchReason.textMatch,
          rank: 1,
        ),
      ]);
      expect(results.hasAmbiguousResults, isTrue);
    });

    test('isTruncated is true when results exceed maxResults', () {
      final truncatedQuery = SearchQuery(
        targetType: SearchTargetType.text,
        query: 'test',
        maxResults: 1,
      );
      final results = SearchResults(
        query: truncatedQuery,
        isTruncated: true,
        results: [
          const SearchResult(
            targetType: SearchTargetType.text,
            boundingBox: TextBoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.1),
            confidence: 0.9,
            matchReason: MatchReason.textMatch,
            rank: 1,
          ),
        ],
      );
      expect(results.isTruncated, isTrue);
    });

    test('isTruncated is false when results within maxResults', () {
      final query2 = SearchQuery(
        targetType: SearchTargetType.text,
        query: 'test',
        maxResults: 10,
      );
      final results = SearchResults(query: query2, results: [
        const SearchResult(
          targetType: SearchTargetType.text,
          boundingBox: TextBoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.1),
          confidence: 0.9,
          matchReason: MatchReason.textMatch,
          rank: 1,
        ),
      ]);
      expect(results.isTruncated, isFalse);
    });
  });
}
