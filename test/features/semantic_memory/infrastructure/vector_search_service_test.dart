/// vector_search_service_test.dart
/// Structural tests for VectorSearchService.
library;

import 'dart:math';
import 'package:test/test.dart';

// ─── Inline mirrors for structural testing ─────────────────────────

enum MemoryType { userPreference, personalFact, conversation, task, project, device, location, instruction, other }

class MemoryEntry {
  final String id;
  final String content;
  final MemoryType memoryType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double importance;
  final List<double>? embedding;
  final bool isActive;

  const MemoryEntry({
    required this.id, required this.content, required this.memoryType,
    required this.createdAt, required this.updatedAt,
    this.importance = 0.5, this.embedding, this.isActive = true,
  });
}

class ScoredMemoryEntry {
  final MemoryEntry entry;
  final double score;
  const ScoredMemoryEntry({required this.entry, required this.score});
}

class VectorSearchService {
  List<ScoredMemoryEntry> search(
    List<double> queryEmbedding,
    List<MemoryEntry> entries, {
    int topK = 5,
    double threshold = 0.0,
  }) {
    final candidates = <ScoredMemoryEntry>[];
    for (final entry in entries) {
      if (entry.embedding == null) continue;
      final score = _cosineSimilarity(queryEmbedding, entry.embedding!);
      if (score >= threshold) {
        candidates.add(ScoredMemoryEntry(entry: entry, score: score));
      }
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.take(topK).toList();
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    return denom == 0 ? 0.0 : dot / denom;
  }
}

void main() {
  group('VectorSearchService', () {
    late VectorSearchService service;
    late DateTime now;

    setUp(() {
      service = VectorSearchService();
      now = DateTime(2025, 1, 15);
    });

    MemoryEntry _makeEntry(String id, List<double> embedding) => MemoryEntry(
      id: id, content: 'Entry $id', memoryType: MemoryType.userPreference,
      createdAt: now, updatedAt: now, embedding: embedding,
    );

    test('search returns scored entries sorted by similarity', () {
      final query = [1.0, 0.0, 0.0];
      final entries = [
        _makeEntry('a', [0.9, 0.1, 0.0]), // high similarity
        _makeEntry('b', [0.1, 0.9, 0.0]), // low similarity
        _makeEntry('c', [1.0, 0.0, 0.0]), // perfect match
      ];
      final results = service.search(query, entries, topK: 3);
      expect(results, hasLength(3));
      expect(results.first.entry.id, 'c'); // perfect match first
      expect(results.first.score, closeTo(1.0, 0.001));
      // 'a' should be second (higher than 'b')
      expect(results[1].entry.id, 'a');
    });

    test('search respects topK limit', () {
      final query = [1.0, 0.0];
      final entries = List.generate(
        10,
        (i) => _makeEntry('e$i', [0.5 + i * 0.05, 0.5 - i * 0.05]),
      );
      final results = service.search(query, entries, topK: 3);
      expect(results, hasLength(3));
    });

    test('search respects threshold', () {
      final query = [1.0, 0.0];
      final entries = [
        _makeEntry('high', [0.99, 0.01]),
        _makeEntry('low', [0.1, 0.9]),
      ];
      final results = service.search(query, entries, threshold: 0.5);
      expect(results, hasLength(1));
      expect(results.first.entry.id, 'high');
    });

    test('entries without embedding are skipped', () {
      final query = [1.0, 0.0];
      final entries = [
        _makeEntry('with', [0.9, 0.1]),
        MemoryEntry(id: 'without', content: 'No emb', memoryType: MemoryType.userPreference,
          createdAt: now, updatedAt: now, embedding: null),
      ];
      final results = service.search(query, entries);
      expect(results, hasLength(1));
      expect(results.first.entry.id, 'with');
    });

    test('empty entries list returns empty results', () {
      final results = service.search([1.0, 0.0], []);
      expect(results, isEmpty);
    });

    test('cosine similarity — identical vectors = 1.0', () {
      final v = [1.0, 2.0, 3.0];
      final results = service.search(v, [_makeEntry('id', v)]);
      expect(results.first.score, closeTo(1.0, 0.0001));
    });

    test('cosine similarity — orthogonal vectors = 0.0', () {
      final results = service.search(
        [1.0, 0.0], [_makeEntry('ortho', [0.0, 1.0])],
      );
      expect(results.first.score, closeTo(0.0, 0.0001));
    });

    test('cosine similarity — opposite vectors = -1.0', () {
      final results = service.search(
        [1.0, 0.0], [_makeEntry('opp', [-1.0, 0.0])],
      );
      expect(results.first.score, closeTo(-1.0, 0.0001));
    });

    test('mismatched embedding dimensions returns 0.0 similarity', () {
      // The implementation returns 0.0 for mismatched lengths
      final results = service.search(
        [1.0, 0.0, 0.0], [_makeEntry('dim', [1.0, 0.0])],
      );
      // Mismatched dims => cosine = 0.0 => below default threshold 0 => still included at threshold 0
      // Actually cosine returns 0.0 and threshold default is 0.0, so it passes
      expect(results, hasLength(1));
      expect(results.first.score, 0.0);
    });
  });
}
