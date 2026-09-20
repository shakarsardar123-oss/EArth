/// memory_repository.dart
/// AURA Assistant – Step 17: Semantic Memory
///
/// Abstract repository for semantic memory – the domain-layer contract.
/// Follows the abstract service pattern from CentralPermissionService.
/// Kurdish-first, local-first, privacy-conscious.
library;

import '../models/memory_entry.dart';
import '../models/memory_type.dart';
import '../models/memory_failure.dart';

/// Abstract repository for semantic memory operations.
///
/// This is the domain-layer contract that the application layer
/// (MemoryManager) depends on. Infrastructure layer provides
/// the concrete implementation.
abstract class MemoryRepository {
  /// Store a new memory entry.
  Future<MemoryResult<MemoryEntry>> store(MemoryEntry entry);

  /// Retrieve a memory entry by [id].
  Future<MemoryResult<MemoryEntry?>> getById(String id);

  /// Update an existing memory entry.
  Future<MemoryResult<MemoryEntry>> update(MemoryEntry entry);

  /// Deactivate (soft-delete) a memory entry by [id].
  Future<MemoryResult<void>> deactivate(String id);

  /// Hard-delete a memory entry by [id].
  Future<MemoryResult<void>> delete(String id);

  /// Retrieve all active memories, optionally filtered by [type].
  Future<MemoryResult<List<MemoryEntry>>> getAll({MemoryType? type});

  /// Retrieve memories created within a date range.
  Future<MemoryResult<List<MemoryEntry>>> getByDateRange({
    DateTime? from,
    DateTime? to,
  });

  /// Count active memories.
  Future<MemoryResult<int>> count({MemoryType? type});

  /// Clear all memories.
  Future<MemoryResult<void>> clearAll();

  /// Search memories by semantic similarity.
  /// [query] is the text to search for; the repository is responsible
  /// for computing its embedding and performing the search.
  Future<MemoryResult<List<MemoryEntry>>> search({
    required String query,
    int limit = 10,
    double minScore = 0.3,
    MemoryType? type,
  });

  /// Find a memory by content similarity (for duplicate detection).
  /// Returns entries that have content similarity above [threshold].
  Future<MemoryResult<List<MemoryEntry>>> findSimilar({
    required String content,
    double threshold = 0.9,
    MemoryType? type,
  });
}
