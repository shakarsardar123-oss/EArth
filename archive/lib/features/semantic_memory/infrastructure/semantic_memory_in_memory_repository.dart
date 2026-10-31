/// semantic_memory_in_memory_repository.dart
/// AURA Assistant – Step 17: Semantic Memory
///
/// Pure in-memory implementation of [MemoryRepository] — no disk I/O.
/// Useful for unit tests. Search/findSimilar use plain content matching
/// (no embeddings) since this repository has no embedding service.
library;

import '../domain/models/memory_entry.dart';
import '../domain/models/memory_failure.dart';
import '../domain/models/memory_type.dart';
import '../domain/repositories/memory_repository.dart';
import '../../../core/errors/result.dart';

class SemanticMemoryInMemoryRepository implements MemoryRepository {
  final Map<String, MemoryEntry> _entries = {};

  @override
  Future<MemoryResult<MemoryEntry>> store(MemoryEntry entry) async {
    _entries[entry.id] = entry;
    return Result.success(entry);
  }

  @override
  Future<MemoryResult<MemoryEntry?>> getById(String id) async {
    return Result.success(_entries[id]);
  }

  @override
  Future<MemoryResult<MemoryEntry>> update(MemoryEntry entry) async {
    if (!_entries.containsKey(entry.id)) {
      return Result.error(
        MemoryFailure.update(message: 'Entry not found', idHint: entry.id, action: 'update'),
      );
    }
    final updated = entry.copyWith(updatedAt: DateTime.now());
    _entries[entry.id] = updated;
    return Result.success(updated);
  }

  @override
  Future<MemoryResult<void>> deactivate(String id) async {
    final existing = _entries[id];
    if (existing == null) {
      return Result.error(
        MemoryFailure.update(message: 'Entry not found', idHint: id, action: 'deactivate'),
      );
    }
    _entries[id] = existing.copyWith(isActive: false);
    return Result.success(null);
  }

  @override
  Future<MemoryResult<void>> delete(String id) async {
    if (!_entries.containsKey(id)) {
      return Result.error(
        MemoryFailure.forget(message: 'Entry not found', idHint: id, action: 'delete'),
      );
    }
    _entries.remove(id);
    return Result.success(null);
  }

  @override
  Future<MemoryResult<List<MemoryEntry>>> getAll({MemoryType? type}) async {
    return Result.success(
      _entries.values.where((e) => type == null || e.memoryType == type).toList(),
    );
  }

  @override
  Future<MemoryResult<List<MemoryEntry>>> getByDateRange({DateTime? from, DateTime? to}) async {
    final filtered = _entries.values.where((e) {
      if (from != null && e.createdAt.isBefore(from)) return false;
      if (to != null && e.createdAt.isAfter(to)) return false;
      return true;
    }).toList();
    return Result.success(filtered);
  }

  @override
  Future<MemoryResult<int>> count({MemoryType? type}) async {
    return Result.success(
      _entries.values.where((e) => type == null || e.memoryType == type).length,
    );
  }

  @override
  Future<MemoryResult<void>> clearAll() async {
    _entries.clear();
    return Result.success(null);
  }

  @override
  Future<MemoryResult<List<MemoryEntry>>> search({
    required String query,
    int limit = 10,
    double minScore = 0.3,
    MemoryType? type,
  }) async {
    final lower = query.toLowerCase();
    final matches = _entries.values
        .where((e) => type == null || e.memoryType == type)
        .where((e) => e.content.toLowerCase().contains(lower))
        .take(limit)
        .toList();
    return Result.success(matches);
  }

  @override
  Future<MemoryResult<List<MemoryEntry>>> findSimilar({
    required String content,
    double threshold = 0.9,
    MemoryType? type,
  }) async {
    final matches = _entries.values
        .where((e) => type == null || e.memoryType == type)
        .where((e) => e.content == content)
        .toList();
    return Result.success(matches);
  }
}
