/// memory_manager_test.dart
/// Structural tests for MemoryManager.
library;

import 'package:flutter_test/flutter_test.dart';

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
  final String id; final String content; final MemoryType memoryType;
  final DateTime createdAt; final DateTime updatedAt; final double importance;
  final String source; final Map<String, dynamic> metadata;
  final List<double>? embedding; final bool isActive;
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

class PolicyCheckResult {
  final bool isAllowed;
  final String? reason;
  const PolicyCheckResult({required this.isAllowed, this.reason});
}

class MemoryPolicy {
  PolicyCheckResult check(String content) {
    // Simplified policy: reject passwords, API keys
    if (content.toLowerCase().contains('password')) {
      return const PolicyCheckResult(isAllowed: false, reason: 'Contains password');
    }
    if (RegExp(r'(?i)api[_\s-]?key').hasMatch(content)) {
      return const PolicyCheckResult(isAllowed: false, reason: 'Contains API key');
    }
    return const PolicyCheckResult(isAllowed: true);
  }
}

/// Stub repository.
class StubRepo {
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
    _entries[e.id] = e; return MemoryResult.success(e);
  }
  MemoryResult<bool> delete(String id) { _entries.remove(id); return MemoryResult.success(true); }
  MemoryResult<int> count({bool? activeOnly}) {
    var r = _entries.values.toList();
    if (activeOnly == true) r = r.where((e) => e.isActive).toList();
    return MemoryResult.success(r.length);
  }
  MemoryResult<bool> clearAll() { _entries.clear(); return MemoryResult.success(true); }
}

class ScoredMemoryEntry {
  final MemoryEntry entry;
  final double score;
  const ScoredMemoryEntry({required this.entry, required this.score});
}

/// Simplified VectorSearch mirror.
class StubVectorSearch {
  List<ScoredMemoryEntry> search(List<double> q, List<MemoryEntry> entries, {int topK = 5, double threshold = 0.0}) {
    // Stub: just return entries with score 0.5 for simplicity
    return entries.where((e) => e.embedding != null).take(topK)
        .map((e) => ScoredMemoryEntry(entry: e, score: 0.5)).toList();
  }
}

class StubEmbedding {
  MemoryResult<List<double>> embed(String text) {
    if (text.isEmpty) return MemoryResult.failure(MemoryFailure(phase: MemoryFailurePhase.embedding, message: 'Empty'));
    return MemoryResult.success([0.1, 0.2, 0.3]);
  }
}

/// Mirror of MemoryManager.
class MemoryManager {
  final StubRepo _repo;
  final MemoryPolicy _policy;
  final StubVectorSearch _vectorSearch;
  final StubEmbedding _embeddingService;

  MemoryManager({
    required StubRepo repository,
    required MemoryPolicy policy,
    required StubVectorSearch vectorSearch,
    required StubEmbedding embeddingService,
  }) : _repo = repository, _policy = policy, _vectorSearch = vectorSearch, _embeddingService = embeddingService;

  MemoryResult<MemoryEntry> remember(String content, MemoryType type, {
    double importance = 0.5, String source = 'unknown', Map<String, dynamic>? metadata,
  }) {
    final policyResult = _policy.check(content);
    if (!policyResult.isAllowed) {
      return MemoryResult.failure(MemoryFailure(phase: MemoryFailurePhase.policy, message: policyResult.reason ?? 'Policy violation'));
    }
    final now = DateTime.now();
    final entry = MemoryEntry(
      id: 'mem_${now.millisecondsSinceEpoch}',
      content: content, memoryType: type,
      createdAt: now, updatedAt: now,
      importance: importance, source: source, metadata: metadata ?? {},
    );
    return _repo.store(entry);
  }

  MemoryResult<List<MemoryEntry>> recall(String query, {int topK = 5, MemoryType? typeFilter}) {
    final embedResult = _embeddingService.embed(query);
    if (embedResult.isFailure) return MemoryResult.failure(embedResult.failure);
    final allResult = _repo.getAll(activeOnly: true);
    if (allResult.isFailure) return MemoryResult.failure(allResult.failure);
    var entries = allResult.value;
    if (typeFilter != null) entries = entries.where((e) => e.memoryType == typeFilter).toList();
    final scored = _vectorSearch.search(embedResult.value, entries, topK: topK);
    return MemoryResult.success(scored.map((s) => s.entry).toList());
  }

  MemoryResult<bool> forget(String id) {
    final existing = _repo.getById(id);
    if (existing.isFailure) return MemoryResult.failure(existing.failure);
    if (existing.value == null) return MemoryResult.failure(
      MemoryFailure(phase: MemoryFailurePhase.storage, message: 'Not found: $id'),
    );
    return _repo.delete(id);
  }

  MemoryResult<MemoryEntry> updateEntry(String id, {String? content, double? importance, MemoryType? memoryType, bool? isActive}) {
    final existing = _repo.getById(id);
    if (existing.isFailure) return MemoryResult.failure(existing.failure);
    if (existing.value == null) return MemoryResult.failure(
      MemoryFailure(phase: MemoryFailurePhase.storage, message: 'Not found: $id'),
    );
    final updated = existing.value!.copyWith(
      content: content, importance: importance, memoryType: memoryType,
      isActive: isActive, updatedAt: DateTime.now(),
    );
    return _repo.update(updated);
  }

  MemoryResult<List<MemoryEntry>> list({MemoryType? type, bool activeOnly = true}) =>
      _repo.getAll(type: type, activeOnly: activeOnly);

  MemoryResult<int> count({bool activeOnly = true}) => _repo.count(activeOnly: activeOnly);
  MemoryResult<bool> clearAll() => _repo.clearAll();

  double inferImportance(String content, MemoryType type) {
    double base = 0.5;
    if ({MemoryType.userPreference, MemoryType.personalFact, MemoryType.instruction}.contains(type)) base = 0.7;
    if (content.length > 100) base += 0.1;
    if (content.length > 500) base += 0.1;
    return base.clamp(0.0, 1.0);
  }
}

void main() {
  group('MemoryManager', () {
    late StubRepo repo;
    late MemoryPolicy policy;
    late StubVectorSearch vectorSearch;
    late StubEmbedding embedding;
    late MemoryManager manager;

    setUp(() {
      repo = StubRepo();
      policy = MemoryPolicy();
      vectorSearch = StubVectorSearch();
      embedding = StubEmbedding();
      manager = MemoryManager(
        repository: repo, policy: policy,
        vectorSearch: vectorSearch, embeddingService: embedding,
      );
    });

    test('remember stores entry successfully', () {
      final result = manager.remember('User likes dark mode', MemoryType.userPreference);
      expect(result.isSuccess, isTrue);
      expect(result.value.content, 'User likes dark mode');
      expect(result.value.memoryType, MemoryType.userPreference);
    });

    test('remember rejects content with password', () {
      final result = manager.remember('My password is secret123', MemoryType.personalFact);
      expect(result.isFailure, isTrue);
      expect(result.failure.phase, MemoryFailurePhase.policy);
    });

    test('remember rejects content with API key', () {
      final result = manager.remember('api_key=abc123', MemoryType.other);
      expect(result.isFailure, isTrue);
      expect(result.failure.phase, MemoryFailurePhase.policy);
    });

    test('remember with custom importance and source', () {
      final result = manager.remember(
        'Important note', MemoryType.task,
        importance: 0.9, source: 'agent_tool',
      );
      expect(result.isSuccess, isTrue);
      expect(result.value.importance, 0.9);
      expect(result.value.source, 'agent_tool');
    });

    test('recall returns matching entries', () {
      manager.remember('First entry', MemoryType.userPreference);
      manager.remember('Second entry', MemoryType.personalFact);
      final result = manager.recall('entry');
      expect(result.isSuccess, isTrue);
      // Our stub returns all entries with embeddings
      expect(result.value, isNotEmpty);
    });

    test('forget removes an entry', () {
      final stored = manager.remember('To forget', MemoryType.other);
      final result = manager.forget(stored.value.id);
      expect(result.isSuccess, isTrue);
      expect(manager.count().value, 0);
    });

    test('forget fails for missing entry', () {
      final result = manager.forget('nonexistent');
      expect(result.isFailure, isTrue);
    });

    test('updateEntry modifies existing entry', () {
      final stored = manager.remember('Original', MemoryType.userPreference);
      final result = manager.updateEntry(stored.value.id, content: 'Updated', importance: 0.9);
      expect(result.isSuccess, isTrue);
      expect(result.value.content, 'Updated');
      expect(result.value.importance, 0.9);
    });

    test('updateEntry fails for missing entry', () {
      final result = manager.updateEntry('missing', content: 'Nope');
      expect(result.isFailure, isTrue);
    });

    test('list returns entries', () {
      manager.remember('A', MemoryType.userPreference);
      manager.remember('B', MemoryType.task);
      final all = manager.list();
      expect(all.isSuccess, isTrue);
      expect(all.value, hasLength(2));

      final filtered = manager.list(type: MemoryType.task);
      expect(filtered.value, hasLength(1));
    });

    test('count returns correct number', () {
      manager.remember('A', MemoryType.userPreference);
      manager.remember('B', MemoryType.personalFact);
      expect(manager.count().value, 2);
    });

    test('clearAll removes everything', () {
      manager.remember('A', MemoryType.userPreference);
      manager.remember('B', MemoryType.task);
      manager.clearAll();
      expect(manager.count().value, 0);
    });

    test('inferImportance returns higher for preferences/facts/instructions', () {
      final prefImportance = manager.inferImportance('short', MemoryType.userPreference);
      final taskImportance = manager.inferImportance('short', MemoryType.task);
      expect(prefImportance, greaterThan(taskImportance));
    });

    test('inferImportance increases with content length', () {
      final short = manager.inferImportance('hi', MemoryType.userPreference);
      final long = manager.inferImportance('a' * 200, MemoryType.userPreference);
      expect(long, greaterThan(short));
    });

    test('inferImportance is clamped to [0, 1]', () {
      final result = manager.inferImportance('x' * 1000, MemoryType.instruction);
      expect(result, inInclusiveRange(0.0, 1.0));
    });
  });
}
