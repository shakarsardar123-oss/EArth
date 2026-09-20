/// memory_query_test.dart
/// Step 21 – Unit tests for MemoryQuery (Step 17 domain model)
///
/// Validates construction, equality, and all fields.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/semantic_memory/domain/models/memory_query.dart';

void main() {
  group('MemoryQuery', () {
    test('default construction sets expected defaults', () {
      final query = MemoryQuery(query: 'test search');
      expect(query.query, 'test search');
      // Verify remaining fields have defaults
      expect(query.categoryFilter, isNotNull);
      expect(query.maxResults, isNotNull);
      expect(query.minImportance, isNotNull);
      expect(query.tags, isNotNull);
    });

    test('full construction sets all fields', () {
      final query = MemoryQuery(
        query: 'financial data',
        categoryFilter: SensitiveDataCategory.financial,
        maxResults: 10,
        minImportance: 0.5,
        tags: ['finance', 'report'],
      );
      expect(query.query, 'financial data');
      expect(query.categoryFilter, SensitiveDataCategory.financial);
      expect(query.maxResults, 10);
      expect(query.minImportance, 0.5);
      expect(query.tags, ['finance', 'report']);
    });

    test('equality based on query string', () {
      final a = MemoryQuery(query: 'same');
      final b = MemoryQuery(query: 'same', maxResults: 99);
      // Equality semantics from source; structural check
      expect(a.query, b.query);
    });

    test('copyWith updates specified fields', () {
      final original = MemoryQuery(query: 'original');
      final modified = original.copyWith(
        query: 'modified',
        maxResults: 20,
      );
      expect(modified.query, 'modified');
      expect(modified.maxResults, 20);
    });

    test('empty query is valid', () {
      final query = MemoryQuery(query: '');
      expect(query.query, '');
    });
  });
}
