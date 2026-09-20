/// local_memory_storage_service_test.dart
/// Structural tests for LocalMemoryStorageService.
library;

import 'package:test/test.dart';

// ─── Inline mirrors for structural testing ─────────────────────────

enum MemoryType { userPreference, personalFact, conversation, task, project, device, location, instruction, other }

enum MemoryFailurePhase { storage, embedding, search, policy, unknown }

class MemoryFailure {
  final MemoryFailurePhase phase;
  final String message;
  MemoryFailure({required this.phase, required this.message});
}

class Result<S, F> {
  final S? _s;
  final F? _f;
  final bool _ok;
  Result._(this._s, this._f, this._ok);
  factory Result.success(S v) => Result._(v, null, true);
  factory Result.failure(F v) => Result._(null, v, false);
  bool get isSuccess => _ok;
  bool get isFailure => !_ok;
  S get value => _s as S;
  F get failure => _f as F;
}

typedef MemoryResult<T> = Result<T, MemoryFailure>;

class MemoryEntry {
  final String id;
  final String content;
  final MemoryType memoryType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double importance;
  final String source;
  final Map<String, dynamic> metadata;
  final List<double>? embedding;
  final bool isActive;

  const MemoryEntry({
    required this.id,
    required this.content,
    required this.memoryType,
    required this.createdAt,
    required this.updatedAt,
    this.importance = 0.5,
    this.source = 'unknown',
    this.metadata = const {},
    this.embedding,
    this.isActive = true,
  });

  MemoryEntry copyWith({
    String? id, String? content, MemoryType? memoryType,
    DateTime? createdAt, DateTime? updatedAt, double? importance,
    String? source, Map<String, dynamic>? metadata,
    List<double>? embedding, bool? isActive, bool clearEmbedding = false,
  }) => MemoryEntry(
    id: id ?? this.id, content: content ?? this.content,
    memoryType: memoryType ?? this.memoryType,
    createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
    importance: importance ?? this.importance, source: source ?? this.source,
    metadata: metadata ?? this.metadata,
    embedding: clearEmbedding ? null : (embedding ?? this.embedding),
    isActive: isActive ?? this.isActive,
  );
}

/// Mirror of LocalMemoryStorageService for testing.
class LocalMemoryStorageService {
  final Map<String, MemoryEntry> _entries = {};
  bool _simulateFailure = false;
  String _failureMessage = 'Storage error';

  void setSimulateFailure(bool simulate, [String message = 'Storage error']) {
    _simulateFailure = simulate;
    _failureMessage = message;
  }

  void setEntry(MemoryEntry entry) => _entries[entry.id] = entry;

  MemoryResult<MemoryEntry> store(MemoryEntry entry) {
    if (_simulateFailure) return MemoryResult.failure(MemoryFailure(phase: MemoryFailurePhase.storage, message: _failureMessage));
    _entries[entry.id] = entry;
    return MemoryResult.success(entry);
  }

  MemoryResult<MemoryEntry?> getById(String id) {
    if (_simulateFailure) return MemoryResult.failure(MemoryFailure(phase: MemoryFailurePhase.storage, message: _failureMessage));
    return MemoryResult.success(_entries[id]);
  }

  MemoryResult<List<MemoryEntry>> getAll({MemoryType? type, bool? activeOnly}) {
    if (_simulateFailure) return MemoryResult.failure(MemoryFailure(phase: MemoryFailurePhase.storage, message: _failureMessage));
    var results = _entries.values.toList();
    if (type != null) results = results.where((e) => e.memoryType == type).toList();
    if (activeOnly == true) results = results.where((e) => e.isActive).toList();
    return MemoryResult.success(results);
  }

  MemoryResult<MemoryEntry> update(MemoryEntry entry) {
    if (_simulateFailure) return MemoryResult.failure(MemoryFailure(phase: MemoryFailurePhase.storage, message: _failureMessage));
    if (!_entries.containsKey(entry.id)) return MemoryResult.failure(MemoryFailure(phase: MemoryFailurePhase.storage, message: 'Not found: ${entry.id}'));
    _entries[entry.id] = entry;
    return MemoryResult.success(entry);
  }

  MemoryResult<bool> delete(String id) {
    if (_simulateFailure) return MemoryResult.failure(MemoryFailure(phase: MemoryFailurePhase.storage, message: _failureMessage));
    if (!_entries.containsKey(id)) return MemoryResult.failure(MemoryFailure(phase: MemoryFailurePhase.storage, message: 'Not found: $id'));
    _entries.remove(id);
    return MemoryResult.success(true);
  }

  MemoryResult<int> count({bool? activeOnly}) {
    if (_simulateFailure) return MemoryResult.failure(MemoryFailure(phase: MemoryFailurePhase.storage, message: _failureMessage));
    var results = _entries.values.toList();
    if (activeOnly == true) results = results.where((e) => e.isActive).toList();
    return MemoryResult.success(results.length);
  }

  MemoryResult<bool> clearAll() {
    if (_simulateFailure) return MemoryResult.failure(MemoryFailure(phase: MemoryFailurePhase.storage, message: _failureMessage));
    _entries.clear();
    return MemoryResult.success(true);
  }
}

void main() {
  group('LocalMemoryStorageService', () {
    late LocalMemoryStorageService service;
    late DateTime now;

    setUp(() {
      service = LocalMemoryStorageService();
      now = DateTime(2025, 1, 15);
    });

    MemoryEntry _makeEntry(String id, {MemoryType type = MemoryType.userPreference, bool active = true}) =>
        MemoryEntry(id: id, content: 'Content $id', memoryType: type, createdAt: now, updatedAt: now, isActive: active);

    test('store and retrieve entry', () {
      final entry = _makeEntry('e1');
      final result = service.store(entry);
      expect(result.isSuccess, isTrue);
      expect(result.value.id, 'e1');

      final fetched = service.getById('e1');
      expect(fetched.isSuccess, isTrue);
      expect(fetched.value?.id, 'e1');
    });

    test('getById returns null for missing entry', () {
      final result = service.getById('missing');
      expect(result.isSuccess, isTrue);
      expect(result.value, isNull);
    });

    test('getAll returns all entries', () {
      service.store(_makeEntry('a'));
      service.store(_makeEntry('b'));
      final result = service.getAll();
      expect(result.isSuccess, isTrue);
      expect(result.value, hasLength(2));
    });

    test('getAll filters by type', () {
      service.store(_makeEntry('a', type: MemoryType.userPreference));
      service.store(_makeEntry('b', type: MemoryType.task));
      final result = service.getAll(type: MemoryType.task);
      expect(result.isSuccess, isTrue);
      expect(result.value, hasLength(1));
      expect(result.value.first.memoryType, MemoryType.task);
    });

    test('getAll filters by activeOnly', () {
      service.store(_makeEntry('a', active: true));
      service.store(_makeEntry('b', active: false));
      final result = service.getAll(activeOnly: true);
      expect(result.value, hasLength(1));
    });

    test('update existing entry succeeds', () {
      service.store(_makeEntry('e1'));
      final updated = _makeEntry('e1').copyWith(content: 'Updated');
      final result = service.update(updated);
      expect(result.isSuccess, isTrue);
      expect(result.value.content, 'Updated');
    });

    test('update non-existing entry fails', () {
      final result = service.update(_makeEntry('missing'));
      expect(result.isFailure, isTrue);
    });

    test('delete existing entry succeeds', () {
      service.store(_makeEntry('e1'));
      final result = service.delete('e1');
      expect(result.isSuccess, isTrue);
      expect(result.value, isTrue);
    });

    test('delete non-existing entry fails', () {
      final result = service.delete('missing');
      expect(result.isFailure, isTrue);
    });

    test('count returns correct count', () {
      service.store(_makeEntry('a'));
      service.store(_makeEntry('b'));
      service.store(_makeEntry('c', active: false));
      expect(service.count().value, 3);
      expect(service.count(activeOnly: true).value, 2);
    });

    test('clearAll removes all entries', () {
      service.store(_makeEntry('a'));
      service.store(_makeEntry('b'));
      final result = service.clearAll();
      expect(result.isSuccess, isTrue);
      expect(service.count().value, 0);
    });

    test('simulateFailure makes all operations fail', () {
      service.setSimulateFailure(true, 'Injected failure');
      expect(service.store(_makeEntry('x')).isFailure, isTrue);
      expect(service.getById('x').isFailure, isTrue);
      expect(service.getAll().isFailure, isTrue);
      expect(service.count().isFailure, isTrue);
      expect(service.clearAll().isFailure, isTrue);
    });

    test('setSimulateFailure can be toggled off', () {
      service.setSimulateFailure(true);
      expect(service.store(_makeEntry('x')).isFailure, isTrue);
      service.setSimulateFailure(false);
      expect(service.store(_makeEntry('y')).isSuccess, isTrue);
    });

    test('setEntry directly injects entry for testing', () {
      final entry = _makeEntry('injected');
      service.setEntry(entry);
      final result = service.getById('injected');
      expect(result.isSuccess, isTrue);
      expect(result.value?.id, 'injected');
    });
  });
}
