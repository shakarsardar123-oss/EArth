/// memory_repository_impl.dart
/// AURA Assistant – Step 17: Semantic Memory
///
/// Concrete implementation of [MemoryRepository] combining
/// storage, embedding, and vector search services.
/// Local-first, no cloud dependency.
library;

import '../domain/models/memory_entry.dart';
import '../domain/models/memory_failure.dart';
import '../domain/models/memory_type.dart';
import '../domain/repositories/memory_repository.dart';
import '../domain/services/memory_embedding_service.dart';
import '../domain/services/memory_storage_service.dart';
import 'hashing_embedding_service.dart';
import 'vector_search_service.dart';
import 'package:texo/features/semantic_memory/infrastructure/local_memory_storage_service.dart';
import '../../../core/errors/result.dart';

/// Concrete [MemoryRepository] implementation.
///
/// Delegates persistence to [MemoryStorageService],
/// embedding computation to [MemoryEmbeddingService],
/// and similarity search to [VectorSearchService].
class MemoryRepositoryImpl implements MemoryRepository {
  final MemoryStorageService _storage;
  final MemoryEmbeddingService _embedding;
  final VectorSearchService _vectorSearch;

  /// Create with the given services, or sensible defaults.
  MemoryRepositoryImpl({
    MemoryStorageService? storage,
    MemoryEmbeddingService? embedding,
    VectorSearchService? vectorSearch,
  })  : _storage = storage ?? LocalMemoryStorageService(),
        _embedding = embedding ?? HashingEmbeddingService(),
        _vectorSearch = vectorSearch ?? VectorSearchService();

  @override
  Future<MemoryResult<MemoryEntry>> store(MemoryEntry entry) async {
    // Compute embedding if not already present.
    MemoryEntry entryToStore = entry;
    if (!entryToStore.hasEmbedding) {
      final embedResult = await _embedding.embed(entry.content);
      if (embedResult.isError) {
        return Result.error(embedResult.error!);
      }
      entryToStore = entryToStore.copyWith(embedding: embedResult.value);
    }
    return _storage.store(entryToStore);
  }

  @override
  Future<MemoryResult<MemoryEntry?>> getById(String id) async {
    return _storage.getById(id);
  }

  @override
  Future<MemoryResult<MemoryEntry>> update(MemoryEntry entry) async {
    // Re-compute embedding if content changed.
    MemoryEntry entryToUpdate = entry;
    if (!entryToUpdate.hasEmbedding) {
      final embedResult = await _embedding.embed(entry.content);
      if (embedResult.isError) {
        return Result.error(embedResult.error!);
      }
      entryToUpdate = entryToUpdate.copyWith(embedding: embedResult.value);
    }
    return _storage.update(entryToUpdate.copyWith(
      updatedAt: DateTime.now(),
    ));
  }

  @override
  Future<MemoryResult<void>> deactivate(String id) async {
    return _storage.deactivate(id);
  }

  @override
  Future<MemoryResult<void>> delete(String id) async {
    return _storage.delete(id);
  }

  @override
  Future<MemoryResult<List<MemoryEntry>>> getAll({MemoryType? type}) async {
    return _storage.getAll(type: type);
  }

  @override
  Future<MemoryResult<List<MemoryEntry>>> getByDateRange({
    DateTime? from,
    DateTime? to,
  }) async {
    return _storage.getByDateRange(from: from, to: to);
  }

  @override
  Future<MemoryResult<int>> count({MemoryType? type}) async {
    return _storage.count(type: type);
  }

  @override
  Future<MemoryResult<void>> clearAll() async {
    return _storage.clearAll();
  }

  @override
  Future<MemoryResult<List<MemoryEntry>>> search({
    required String query,
    int limit = 10,
    double minScore = 0.3,
    MemoryType? type,
  }) async {
    // Compute query embedding.
    final embedResult = await _embedding.embed(query);
    if (embedResult.isError) {
      return Result.error(embedResult.error!);
    }

    // Retrieve candidate entries.
    final allResult = await _storage.getAll(type: type);
    if (allResult.isError) {
      return Result.error(allResult.error!);
    }

    // Perform vector search.
    final searchResult = await _vectorSearch.search(
      entries: allResult.value!,
      queryEmbedding: embedResult.value!,
      topK: limit,
      minScore: minScore,
    );
    if (searchResult.isError) {
      return Result.error(searchResult.error!);
    }

    // Strip scores – return only entries.
    return Result.success(
      searchResult.value!.map((s) => s.entry).toList(),
    );
  }

  @override
  Future<MemoryResult<List<MemoryEntry>>> findSimilar({
    required String content,
    double threshold = 0.9,
    MemoryType? type,
  }) async {
    // Compute content embedding.
    final embedResult = await _embedding.embed(content);
    if (embedResult.isError) {
      return Result.error(embedResult.error!);
    }

    // Retrieve candidate entries.
    final allResult = await _storage.getAll(type: type);
    if (allResult.isError) {
      return Result.error(allResult.error!);
    }

    // Perform vector search with high threshold.
    final searchResult = await _vectorSearch.search(
      entries: allResult.value!,
      queryEmbedding: embedResult.value!,
      topK: 50,
      minScore: threshold,
    );
    if (searchResult.isError) {
      return Result.error(searchResult.error!);
    }

    return Result.success(
      searchResult.value!.map((s) => s.entry).toList(),
    );
  }
}
