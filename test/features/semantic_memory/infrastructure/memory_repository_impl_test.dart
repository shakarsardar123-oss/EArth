/// memory_repository_impl_test.dart
/// Structural tests for MemoryRepositoryImpl (auto-embeds on store/update).
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
  final S? _s; final F? _f; final bool _ok;
  Result._(this._s, this._f, this._ok);
  factory Result.success(S v) => Result._(v, null, true);
  factory Result.failure(F v) => Result._(null, v, false);
  bool get isSuccess => _ok; bool get isFailure => !_ok;
  S get value => _s as S; F get failure => _f as F;
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
    required this.id, required this.content, required this.memoryType,
    required this.createdAt, required this.updatedAt,
    this.importance = 0.5, this.source = 'unknown', this.metadata = const {},
    this.embedding, this.isActive = true,
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

/// Stub storage service mirror.
class StubStorage {
  final Map<String, MemoryEntry> _entries = {};
  MemoryResult<MemoryEntry> store(MemoryEntry e) { _entries[e.id] = e; return MemoryResult.success(e); }
  MemoryResult<MemoryEntry?> getById(String id) => MemoryResult.success(_entries[id]);
  MemoryResult<List<MemoryEntry>> getAll({MemoryType? type, bool? activeOnly}) {
    var r = _entries.values.toList();
    if (type != null) r = r.where((e) => e.memoryType == type).toList();
    if (activeOnly == true) r = r.where((e) => e.isActive).toList();
    return MemoryResult.success(r);
  }
  MemoryResult<MemoryEntry> update(MemoryEntry e) {
    if (!_entries.containsKey(e.id)) return MemoryResult.failure(MemoryFailure(phase: MemoryFailurePhase.storage, message: 'Not found'));
    _entries[e.id] = e;
    return MemoryResult.success(e);
  }
  MemoryResult<bool> delete(String id) {
    _entries.remove(id);
    return MemoryResult.success(true);
  }
  MemoryResult<int> count({bool? activeOnly}) {
    var r = _entries.values.toList();
    if (activeOnly == true) r = r.where((e) => e.isActive).toList();
    return MemoryResult.success(r.length);
  }
  MemoryResult<bool> clearAll() { _entries.clear(); return MemoryResult.success(true); }
}

/// Stub embedding service mirror.
class StubEmbedding {
  int dimensions = 8;
  MemoryResult<List<double>> embed(String text) {
    if (text.isEmpty) return MemoryResult.failure(MemoryFailure(phase: MemoryFailurePhase.embedding, message: 'Empty'));
    return MemoryResult.success(List.generate(dimensions, (i) => (text.codeUnits[i % text.codeUnits.length] % 100) / 100.0));
  }
}

/// Mirror of MemoryRepositoryImpl — auto-embeds on store/update.
class MemoryRepositoryImpl {
  final StubStorage _storage;
  final StubEmbedding _embedding;

  MemoryRepositoryImpl({required StubStorage storage, required StubEmbedding embedding})
    : _storage = storage, _embedding = embedding;

  MemoryResult<MemoryEntry> store(MemoryEntry entry) {
    final embedResult = _embedding.embed(entry.content);
    if (embedResult.isFailure) return MemoryResult.failure(embedResult.failure);
    final withEmbedding = entry.copyWith(embedding: embedResult.value);
    return _storage.store(withEmbedding);
  }

  MemoryResult<MemoryEntry?> getById(String id) => _storage.getById(id);
  MemoryResult<List<MemoryEntry>> getAll({MemoryType? type, bool? activeOnly}) => _storage.getAll(type: type, activeOnly: activeOnly);

  MemoryResult<MemoryEntry> update(MemoryEntry entry) {
    final embedResult = _embedding.embed(entry.content);
    if (embedResult.isFailure) return MemoryResult.failure(embedResult.failure);
    final withEmbedding = entry.copyWith(embedding: embedResult.value);
    return _storage.update(withEmbedding);
  }

  MemoryResult<bool> delete(String id) => _storage.delete(id);
  MemoryResult<int> count({bool? activeOnly}) => _storage.count(activeOnly: activeOnly);
  MemoryResult<bool> clearAll() => _storage.clearAll();
}

void main() {
  group('MemoryRepositoryImpl', () {
    late StubStorage storage;
    late StubEmbedding embedding;
    late MemoryRepositoryImpl repo;
    late DateTime now;

    setUp(() {
      storage = StubStorage();
      embedding = StubEmbedding();
      repo = MemoryRepositoryImpl(storage: storage, embedding: embedding);
      now = DateTime(2025, 1, 15);
    });

    MemoryEntry _makeEntry(String id, {String content = 'Test content'}) => MemoryEntry(
      id: id, content: content, memoryType: MemoryType.userPreference,
      createdAt: now, updatedAt: now,
    );

    test('store auto-embeds the entry', () {
      final entry = _makeEntry('e1');
      expect(entry.embedding, isNull);

      final result = repo.store(entry);
      expect(result.isSuccess, isTrue);
      expect(result.value.embedding, isNotNull);
      expect(result.value.embedding, hasLength(8));
    });

    test('stored entry can be retrieved with embedding', () {
      repo.store(_makeEntry('e1'));
      final fetched = repo.getById('e1');
      expect(fetched.isSuccess, isTrue);
      expect(fetched.value?.embedding, isNotNull);
      expect(fetched.value?.embedding, hasLength(8));
    });

    test('store fails if embedding service fails', () {
      final entry = _makeEntry('e1', content: ''); // empty content => embed fails
      final result = repo.store(entry);
      expect(result.isFailure, isTrue);
      expect(result.failure.phase, MemoryFailurePhase.embedding);
    });

    test('update auto-embeds the entry', () {
      repo.store(_makeEntry('e1', content: 'Original'));
      final updated = _makeEntry('e1', content: 'Updated content');
      final result = repo.update(updated);
      expect(result.isSuccess, isTrue);
      expect(result.value.content, 'Updated content');
      expect(result.value.embedding, isNotNull);
    });

    test('update fails if embedding fails', () {
      repo.store(_makeEntry('e1'));
      final updated = _makeEntry('e1', content: '');
      final result = repo.update(updated);
      expect(result.isFailure, isTrue);
      expect(result.failure.phase, MemoryFailurePhase.embedding);
    });

    test('update fails if entry not in storage', () {
      final result = repo.update(_makeEntry('missing'));
      expect(result.isFailure, isTrue);
      expect(result.failure.phase, MemoryFailurePhase.storage);
    });

    test('getAll delegates to storage', () {
      repo.store(_makeEntry('a'));
      repo.store(_makeEntry('b'));
      final result = repo.getAll();
      expect(result.isSuccess, isTrue);
      expect(result.value, hasLength(2));
    });

    test('getAll with type filter', () {
      repo.store(_makeEntry('a'));
      repo.store(MemoryEntry(
        id: 'b', content: 'Task', memoryType: MemoryType.task,
        createdAt: now, updatedAt: now,
      ));
      final result = repo.getAll(type: MemoryType.task);
      expect(result.value, hasLength(1));
    });

    test('delete delegates to storage', () {
      repo.store(_makeEntry('e1'));
      final result = repo.delete('e1');
      expect(result.isSuccess, isTrue);
      expect(repo.getById('e1').value, isNull);
    });

    test('count delegates to storage', () {
      repo.store(_makeEntry('a'));
      repo.store(_makeEntry('b'));
      expect(repo.count().value, 2);
    });

    test('clearAll delegates to storage', () {
      repo.store(_makeEntry('a'));
      repo.store(_makeEntry('b'));
      repo.clearAll();
      expect(repo.count().value, 0);
    });

    test('embedding is deterministic for same content', () {
      repo.store(_makeEntry('e1', content: 'hello'));
      repo.store(_makeEntry('e2', content: 'hello'));
      final e1 = repo.getById('e1').value!;
      final e2 = repo.getById('e2').value!;
      expect(e1.embedding, equals(e2.embedding));
    });
  });
}
