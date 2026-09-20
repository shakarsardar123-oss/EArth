/// vector_search_service.dart
/// AURA Assistant – Step 17: Semantic Memory
///
/// Vector search service using cosine similarity.
/// Pure Dart implementation — no external dependencies.
/// Local-first, privacy-conscious.
library;

import 'dart:math';

import '../domain/models/memory_entry.dart';
import '../domain/models/memory_failure.dart';
import '../../../core/errors/result.dart';

/// A scored memory entry from a vector search.
class ScoredMemoryEntry {
  final MemoryEntry entry;
  final double score;

  const ScoredMemoryEntry({required this.entry, required this.score});

  @override
  String toString() =>
      'ScoredMemoryEntry(score: ${score.toStringAsFixed(4)}, '
      'id: ${entry.id})';
}

/// Vector search service that ranks memory entries by cosine similarity.
///
/// This is a pure Dart implementation that operates on in-memory
/// entries with pre-computed embeddings. No cloud or external
/// vector database is required.
class VectorSearchService {
  /// Compute cosine similarity between two vectors.
  ///
  /// Returns a value in [-1, 1], where 1 = identical direction,
  /// 0 = orthogonal, -1 = opposite direction.
  /// Returns 0.0 if either vector is empty or has zero norm.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (var i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = sqrt(normA) * sqrt(normB);
    if (denominator == 0.0) return 0.0;
    return dotProduct / denominator;
  }

  /// Search [entries] for the most similar items to [queryEmbedding].
  ///
  /// Returns up to [topK] results sorted by descending similarity.
  /// Only entries with embeddings are considered; entries without
  /// embeddings are silently skipped.
  ///
  /// [minScore] filters out entries below the threshold (default 0.0).
  Future<MemoryResult<List<ScoredMemoryEntry>>> search({
    required List<MemoryEntry> entries,
    required List<double> queryEmbedding,
    int topK = 10,
    double minScore = 0.0,
  }) async {
    try {
      final scored = <ScoredMemoryEntry>[];

      for (final entry in entries) {
        if (!entry.isActive) continue;
        if (!entry.hasEmbedding) continue;

        final score = cosineSimilarity(queryEmbedding, entry.embedding!);
        if (score >= minScore) {
          scored.add(ScoredMemoryEntry(entry: entry, score: score));
        }
      }

      // Sort by descending score.
      scored.sort((a, b) => b.score.compareTo(a.score));

      // Return top K.
      return Result.success(scored.take(topK).toList());
    } catch (e) {
      return Result.error(MemoryFailure.search(
        queryHint: 'vector_search',
        cause: e,
      ));
    }
  }
}
