/// local_memory_storage_service.dart
/// AURA Assistant – Step 17: Semantic Memory
///
/// Local in-memory implementation of [MemoryStorageService].
/// Designed for development/testing; production should use SQLite/Hive.
/// Kurdish-first, local-first, privacy-conscious.
library;

import '../domain/models/memory_entry.dart';
import '../domain/models/memory_failure.dart';
import '../domain/models/memory_type.dart';
import '../domain/services/memory_storage_service.dart';
import '../../../core/errors/result.dart';

/// In-memory local storage for semantic memory entries.
class LocalMemoryStorageService implements MemoryStorageService {
  final Map<String, MemoryEntry> _store = {};
  bool _simulateFailure = false;
  MemoryFailurePhase? _failurePhase;

  // ─── Test helpers ─────────────────────────────────────────────────

  void setSimulateFailure(MemoryFailurePhase? phase) {
    _simulateFailure = phase != null;
    _failurePhase = phase;
  }

  void setEntry(MemoryEntry entry) {
    _store[entry.id] = entry;
  }

  int get debugEntryCount => _store.length;

  bool _shouldFail(MemoryFailurePhase phase) =>
      _simulateFailure && _failurePhase == phase;

  // ─── MemoryStorageService implementation ─────────────────────────

  @override
  Future<MemoryResult<MemoryEntry>> store(MemoryEntry entry) async {
    if (_shouldFail(MemoryFailurePhase.store)) {
      return Result.error(MemoryFailure.store(cause: 'simulated'));
    }
    _store[entry.id] = entry;
    return Result.success(entry);
  }

  @override
  Future<MemoryResult<MemoryEntry?>> getById(String id) async {
    if (_shouldFail(MemoryFailurePhase.recall)) {
      return Result.error(MemoryFailure.recall(cause: 'simulated'));
    }
    return Result.success(_store[id]);
  }

  @override
  Future<MemoryResult<MemoryEntry>> update(MemoryEntry entry) async {
    if (_shouldFail(MemoryFailurePhase.update)) {
      return Result.error(MemoryFailure.update(cause: 'simulated'));
    }
    if (!_store.containsKey(entry.id)) {
      return Result.error(MemoryFailure.update(
        idHint: entry.id,
        action: 'not_found',
      ));
    }
    _store[entry.id] = entry;
    return Result.success(entry);
  }

  @override
  Future<MemoryResult<void>> deactivate(String id) async {
    if (_shouldFail(MemoryFailurePhase.forget)) {
      return Result.error(MemoryFailure.forget(cause: 'simulated'));
    }
    final entry = _store[id];
    if (entry == null) {
      return Result.error(MemoryFailure.forget(
        idHint: id,
        action: 'not_found',
      ));
    }
    _store[id] = entry.copyWith(isActive: false);
    return Result.success(null);
  }

  @override
  Future<MemoryResult<void>> delete(String id) async {
    if (_shouldFail(MemoryFailurePhase.forget)) {
      return Result.error(MemoryFailure.forget(cause: 'simulated'));
    }
    if (!_store.containsKey(id)) {
      return Result.error(MemoryFailure.forget(
        idHint: id,
        action: 'not_found',
      ));
    }
    _store.remove(id);
    return Result.success(null);
  }

  @override
  Future<MemoryResult<List<MemoryEntry>>> getAll({MemoryType? type}) async {
    if (_shouldFail(MemoryFailurePhase.recall)) {
      return Result.error(MemoryFailure.recall(cause: 'simulated'));
    }
    var entries = _store.values.where((e) => e.isActive).toList();
    if (type != null) {
      entries = entries.where((e) => e.memoryType == type).toList();
    }
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Result.success(entries);
  }

  @override
  Future<MemoryResult<List<MemoryEntry>>> getByDateRange({
    DateTime? from,
    DateTime? to,
  }) async {
    if (_shouldFail(MemoryFailurePhase.recall)) {
      return Result.error(MemoryFailure.recall(cause: 'simulated'));
    }
    var entries = _store.values
        .where((e) => e.isActive)
        .where((e) {
          if (from != null && e.createdAt.isBefore(from)) return false;
          if (to != null && e.createdAt.isAfter(to)) return false;
          return true;
        })
        .toList();
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Result.success(entries);
  }

  @override
  Future<MemoryResult<int>> count({MemoryType? type}) async {
    if (_shouldFail(MemoryFailurePhase.recall)) {
      return Result.error(MemoryFailure.recall(cause: 'simulated'));
    }
    var entries = _store.values.where((e) => e.isActive);
    if (type != null) {
      entries = entries.where((e) => e.memoryType == type);
    }
    return Result.success(entries.length);
  }

  @override
  Future<MemoryResult<void>> clearAll() async {
    if (_shouldFail(MemoryFailurePhase.forget)) {
      return Result.error(MemoryFailure.forget(cause: 'simulated'));
    }
    _store.clear();
    return Result.success(null);
  }
}
