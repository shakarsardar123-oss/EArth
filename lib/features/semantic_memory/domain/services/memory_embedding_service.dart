/// memory_embedding_service.dart
/// AURA Assistant – Step 17: Semantic Memory
///
/// Abstract service for computing vector embeddings from text.
/// Follows the abstract service pattern.
/// Local-first: no cloud dependency, no hardcoded API keys.
library;

import '../models/memory_failure.dart';
import '../../../../core/errors/result.dart';

/// Abstract interface for computing text embeddings.
///
/// Implementations may use local on-device models (e.g. TFLite, ONNX)
/// or stubs for development/testing. No cloud API keys are ever
/// hardcoded — the contract is entirely local-first.
abstract class MemoryEmbeddingService {
  /// The dimensionality of vectors produced by this service.
  int get dimension;

  /// Compute an embedding vector for the given [text].
  /// Returns a list of doubles of length [dimension] or a [MemoryFailure].
  Future<MemoryResult<List<double>>> embed(String text);

  /// Batch-compute embeddings for multiple texts.
  /// Default implementation calls [embed] sequentially.
  Future<MemoryResult<List<List<double>>>> embedBatch(List<String> texts) async {
    final results = <List<double>>[];
    for (final text in texts) {
      final result = await embed(text);
      if (result.isError) {
        return Result.error(result.error!);
      }
      results.add(result.value!);
    }
    return Result.success(results);
  }
}
