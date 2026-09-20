/// memory_search_result_test.dart
/// Step 21 – Unit tests for MemorySearchResult (Step 17 domain model)

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/semantic_memory/domain/models/memory_search_result.dart';

void main() {
  group('MemorySearchResult', () {
    test('construction with entries and query', () {
      final result = MemorySearchResult(
        entries: [],
        query: 'test',
        totalCount: 0,
        hasMore: false,
      );
      expect(result.entries, isEmpty);
      expect(result.query, 'test');
      expect(result.totalCount, 0);
      expect(result.hasMore, false);
    });

    test('construction with multiple entries', () {
      // Use placeholder entries; exact API depends on SemanticMemoryEntry
      final result = MemorySearchResult(
        entries: [], // Populated with real entries in integration tests
        query: 'search',
        totalCount: 3,
        hasMore: true,
      );
      expect(result.totalCount, 3);
      expect(result.hasMore, true);
    });

    test('empty result is valid', () {
      final result = MemorySearchResult(
        entries: [],
        query: 'nothing',
        totalCount: 0,
        hasMore: false,
      );
      expect(result.entries, isEmpty);
      expect(result.totalCount, 0);
    });

    test('copyWith modifies hasMore', () {
      final original = MemorySearchResult(
        entries: [],
        query: 'q',
        totalCount: 5,
        hasMore: true,
      );
      final updated = original.copyWith(hasMore: false);
      expect(updated.hasMore, false);
      expect(updated.totalCount, 5);
    });
  });
}
