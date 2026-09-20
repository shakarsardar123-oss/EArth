/// stub_memory_embedding_service.dart
/// AURA Assistant – Step 17: Semantic Memory
///
/// Stub implementation of [MemoryEmbeddingService] for development/testing.
/// Produces deterministic hash-based pseudo-embeddings.
/// No real ML model involved — suitable for structural tests only.
/// Local-first, no cloud dependency, no hardcoded API keys.
library;

import 'dart:math';

import '../domain/models/memory_failure.dart';
import '../domain/services/memory_embedding_service.dart';
import '../../../core/errors/result.dart';

/// Stub embedding service that generates deterministic pseudo-vectors.
///
/// Uses a simple hash-based approach: each character contributes to
/// a fixed-dimensional vector. Not semantically meaningful but
/// deterministic for the same input — suitable for testing.
class StubMemoryEmbeddingService extends MemoryEmbeddingService {
  final int _dimension;
  bool _simulateFailure = false;

  /// Create a stub with the given vector dimension (default 64).
  StubMemoryEmbeddingService({int dimension = 64})
      : _dimension = dimension;

  @override
  int get dimension => _dimension;

  // ─── Test helpers ─────────────────────────────────────────────────

  /// Simulate an embedding failure on the next call.
  void setSimulateFailure(bool fail) => _simulateFailure = fail;

  // ─── MemoryEmbeddingService implementation ───────────────────────

  @override
  Future<MemoryResult<List<double>>> embed(String text) async {
    if (_simulateFailure) {
      return Result.error(MemoryFailure.embedding(cause: 'simulated'));
    }
    if (text.isEmpty) {
      return Result.success(List.filled(_dimension, 0.0));
    }

    // Deterministic pseudo-embedding: hash-based.
    final vector = List<double>.filled(_dimension, 0.0);
    final rng = Random(text.hashCode);
    for (var i = 0; i < _dimension; i++) {
      vector[i] = rng.nextDouble() * 2.0 - 1.0; // range [-1, 1]
    }
    // Normalize to unit length.
    final norm = sqrt(vector.fold(0.0, (sum, v) => sum + v * v));
    if (norm > 0) {
      for (var i = 0; i < _dimension; i++) {
        vector[i] /= norm;
      }
    }
    return Result.success(vector);
  }
}
