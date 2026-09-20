/// Tests for ScreenSearchState — Step 10 screen-search subsystem.
library;

import 'package:aura_assistant/core/screen_search/search_result.dart';
import 'package:aura_assistant/core/screen_search/search_state.dart';
import 'package:aura_assistant/core/screen_understanding/screen_understanding_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ----------------------------------------------------------------
  // ScreenSearchStatus
  // ----------------------------------------------------------------
  group('ScreenSearchStatus', () {
    test('has all expected values', () {
      expect(ScreenSearchStatus.values, containsAll([
        ScreenSearchStatus.idle,
        ScreenSearchStatus.searching,
        ScreenSearchStatus.success,
        ScreenSearchStatus.noResults,
        ScreenSearchStatus.error,
        ScreenSearchStatus.cancelled,
      ]));
    });
  });

  // ----------------------------------------------------------------
  // ScreenSearchState — default construction
  // ----------------------------------------------------------------
  group('ScreenSearchState defaults', () {
    test('default state is idle', () {
      const state = ScreenSearchState();
      expect(state.status, ScreenSearchStatus.idle);
      expect(state.results, isNull);
      expect(state.errorMessage, isNull);
      expect(state.searchCount, 0);
      expect(state.lastSearchTimestamp, isNull);
      expect(state.isIdle, isTrue);
      expect(state.isSearching, isFalse);
      expect(state.hasResults, isFalse);
      expect(state.hasError, isFalse);
    });
  });

  // ----------------------------------------------------------------
  // ScreenSearchState — computed properties
  // ----------------------------------------------------------------
  group('ScreenSearchState computed props', () {
    test('isSearching is true when status is searching', () {
      const state = ScreenSearchState(status: ScreenSearchStatus.searching);
      expect(state.isSearching, isTrue);
      expect(state.isIdle, isFalse);
    });

    test('hasResults is true when status is success and results non-null', () {
      const query = SearchQuery(
        targetType: SearchTargetType.text,
        query: 'test',
      );
      final results = SearchResults(query: query, results: const []);
      final state = ScreenSearchState(
        status: ScreenSearchStatus.success,
        results: results,
      );
      expect(state.hasResults, isTrue);
    });

    test('hasError is true when status is error', () {
      const state = ScreenSearchState(
        status: ScreenSearchStatus.error,
        errorMessage: 'Something went wrong',
      );
      expect(state.hasError, isTrue);
      expect(state.errorMessage, 'Something went wrong');
    });

    test('isIdle is true only when status is idle', () {
      const state = ScreenSearchState(status: ScreenSearchStatus.idle);
      expect(state.isIdle, isTrue);

      const searching = ScreenSearchState(status: ScreenSearchStatus.searching);
      expect(searching.isIdle, isFalse);
    });
  });

  // ----------------------------------------------------------------
  // ScreenSearchState — lastSearchTimestamp as int (epoch millis)
  // ----------------------------------------------------------------
  group('ScreenSearchState lastSearchTimestamp', () {
    test('lastSearchTimestamp is int? (epoch millis)', () {
      const ts = 1724500000000; // some epoch millis
      const state = ScreenSearchState(lastSearchTimestamp: ts);
      expect(state.lastSearchTimestamp, ts);
      expect(state.lastSearchTimestamp, isA<int>());
    });

    test('lastSearchTimestamp defaults to null', () {
      const state = ScreenSearchState();
      expect(state.lastSearchTimestamp, isNull);
    });
  });

  // ----------------------------------------------------------------
  // ScreenSearchState — copyWith
  // ----------------------------------------------------------------
  group('ScreenSearchState copyWith', () {
    test('copyWith preserves fields and overrides specified ones', () {
      const query = SearchQuery(
        targetType: SearchTargetType.text,
        query: 'test',
      );
      final results = SearchResults(query: query, results: const []);
      const ts = 1724500000000;

      final state = ScreenSearchState(
        status: ScreenSearchStatus.success,
        results: results,
        searchCount: 3,
        lastSearchTimestamp: ts,
      );

      final updated = state.copyWith(
        status: ScreenSearchStatus.searching,
        searchCount: 4,
      );

      expect(updated.status, ScreenSearchStatus.searching);
      expect(updated.results, results); // preserved
      expect(updated.searchCount, 4);
      expect(updated.lastSearchTimestamp, ts); // preserved
    });

    test('copyWith can update lastSearchTimestamp with int', () {
      const state = ScreenSearchState();
      const newTs = 1724567890000;
      final updated = state.copyWith(lastSearchTimestamp: newTs);
      expect(updated.lastSearchTimestamp, newTs);
    });

    test('copyWith can set error state', () {
      const state = ScreenSearchState(status: ScreenSearchStatus.searching);
      final updated = state.copyWith(
        status: ScreenSearchStatus.error,
        errorMessage: 'Network error',
      );
      expect(updated.status, ScreenSearchStatus.error);
      expect(updated.errorMessage, 'Network error');
    });
  });

  // ----------------------------------------------------------------
  // ScreenSearchState — searchCount
  // ----------------------------------------------------------------
  group('ScreenSearchState searchCount', () {
    test('searchCount defaults to 0', () {
      const state = ScreenSearchState();
      expect(state.searchCount, 0);
    });

    test('searchCount is set correctly', () {
      const state = ScreenSearchState(searchCount: 5);
      expect(state.searchCount, 5);
    });
  });
}
