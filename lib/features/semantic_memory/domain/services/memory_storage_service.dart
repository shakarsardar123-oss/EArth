/// memory_storage_service.dart
/// AURA Assistant – Step 17: Semantic Memory
library;

import '../models/memory_entry.dart';
import '../models/memory_failure.dart';
import '../models/memory_type.dart';

export '../models/memory_type.dart' show MemoryType;

/// Abstract interface for semantic memory persistence.
abstract class MemoryStorageService {
  Future<MemoryResult<MemoryEntry>> store(MemoryEntry entry);
  Future<MemoryResult<MemoryEntry?>> getById(String id);
  Future<MemoryResult<MemoryEntry>> update(MemoryEntry entry);
  Future<MemoryResult<void>> deactivate(String id);
  Future<MemoryResult<void>> delete(String id);
  Future<MemoryResult<List<MemoryEntry>>> getAll({MemoryType? type});
  Future<MemoryResult<List<MemoryEntry>>> getByDateRange({
    DateTime? from,
    DateTime? to,
  });
  Future<MemoryResult<int>> count({MemoryType? type});
  Future<MemoryResult<void>> clearAll();
}
