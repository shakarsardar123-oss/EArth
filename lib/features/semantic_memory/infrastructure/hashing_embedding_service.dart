/// hashing_embedding_service.dart
/// AURA Assistant – Step 17: Semantic Memory
///
/// Local, dependency-free embedding service using the feature-hashing
/// trick over word n-grams (the technique behind scikit-learn's
/// HashingVectorizer / Vowpal Wabbit).
///
/// [StubMemoryEmbeddingService] hashed the *whole string* into a random
/// seed, so two texts sharing most of their words still produced
/// unrelated vectors — semantic search over remembered content was
/// effectively random. This service hashes individual words (and word
/// pairs), so texts that share vocabulary end up with vectors that are
/// genuinely close in cosine distance.
///
/// This is not a neural embedding model — it has no notion of synonyms
/// or meaning beyond shared words/n-grams — but it is a real, local,
/// no-cloud, no-API-key technique, and can be swapped for an on-device
/// ML model later without changing the [MemoryEmbeddingService] contract.
library;

import 'dart:math';

import '../domain/models/memory_failure.dart';
import '../domain/services/memory_embedding_service.dart';
import '../../../core/errors/result.dart';

class HashingEmbeddingService extends MemoryEmbeddingService {
  final int _dimension;

  /// Create with the given vector dimension.
  ///
  /// Kept at 64 (the same default the old stub used) so it stays
  /// compatible with any embeddings already persisted by
  /// [LocalMemoryStorageService] — changing this later requires
  /// re-embedding stored entries.
  HashingEmbeddingService({int dimension = 64}) : _dimension = dimension;

  @override
  int get dimension => _dimension;

  @override
  Future<MemoryResult<List<double>>> embed(String text) async {
    if (text.isEmpty) {
      return Result.success(List.filled(_dimension, 0.0));
    }

    final tokens = _tokenize(text);
    if (tokens.isEmpty) {
      return Result.success(List.filled(_dimension, 0.0));
    }

    // Unigrams + adjacent-word bigrams: bigrams give the vector a little
    // word-order sensitivity ("wake up" vs "up wake") without needing a
    // real model.
    final features = <String>[...tokens];
    for (var i = 0; i < tokens.length - 1; i++) {
      features.add('${tokens[i]}_${tokens[i + 1]}');
    }

    final vector = List<double>.filled(_dimension, 0.0);
    for (final feature in features) {
      final h = _fnv1a(feature);
      final index = h % _dimension;
      // Sign hashing (Weinberger et al., 2009) reduces the systematic
      // bias plain hashed counts would otherwise introduce.
      final sign = ((h ~/ _dimension) & 1) == 0 ? 1.0 : -1.0;
      vector[index] += sign;
    }

    // Normalize to unit length so downstream cosine similarity behaves
    // the way it would for a real embedding.
    final norm = sqrt(vector.fold(0.0, (sum, v) => sum + v * v));
    if (norm > 0) {
      for (var i = 0; i < _dimension; i++) {
        vector[i] /= norm;
      }
    }
    return Result.success(vector);
  }

  /// Lowercase, strip punctuation, split on whitespace. Relies only on
  /// whitespace boundaries (not Latin-specific casing/stemming rules),
  /// so it works reasonably for both Latin and Kurdish (Sorani) text.
  List<String> _tokenize(String text) {
    final cleaned = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    return cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  }

  /// FNV-1a — a small, fast, stable string hash. Deterministic across
  /// runs and platforms (unlike Dart's [String.hashCode], which is only
  /// guaranteed stable within a single isolate run, not across app
  /// restarts or platforms).
  int _fnv1a(String input) {
    const fnvPrime = 0x01000193;
    var hash = 0x811c9dc5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash;
  }
}
