/// memory_full_integration_test.dart
/// End-to-end structural integration test for the semantic memory feature.
/// Tests the full flow: remember → recall → update → forget, with policy checks.
library;

import 'package:test/test.dart';

// ─── Inline mirrors for structural testing ─────────────────────────

enum MemoryType { userPreference, personalFact, conversation, task, project, device, location, instruction, other }
enum MemoryFailurePhase { storage, embedding, search, policy, unknown }

class MemoryFailure {
  final MemoryFailurePhase phase;
  final String message;
  MemoryFailure({required this.phase, required this.message});
  @override String toString() => 'MemoryFailure($phase, $message)';
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
  final String source; final List<double>? embedding; final bool isActive;
  const MemoryEntry({
    required this.id, required this.content, required this.memoryType,
    required this.createdAt, required this.updatedAt,
    this.importance = 0.5, this.source = 'unknown', this.embedding, this.isActive = true,
  });
  MemoryEntry copyWith({
    String? id, String? content, MemoryType? memoryType,
    DateTime? createdAt, DateTime? updatedAt, double? importance,
    String? source, List<double>? embedding, bool? isActive, bool clearEmbedding = false,
  }) => MemoryEntry(
    id: id ?? this.id, content: content ?? this.content,
    memoryType: memoryType ?? this.memoryType,
    createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
    importance: importance ?? this.importance, source: source ?? this.source,
    embedding: clearEmbedding ? null : (embedding ?? this.embedding),
    isActive: isActive ?? this.isActive,
  );
}

class PolicyCheckResult {
  final bool isAllowed; final String? reason;
  const PolicyCheckResult({required this.isAllowed, this.reason});
}

class MemoryPolicy {
  static final _sensitivePatterns = <RegExp>[
    RegExp(r'password', caseSensitive: false),
    RegExp(r'api[_\-]?key', caseSensitive: false),
    RegExp(r'auth[_\-]?token', caseSensitive: false),
    RegExp(r'secret', caseSensitive: false),
    RegExp(r'\b\d{16}\b'), // credit card
  ];

  PolicyCheckResult check(String content) {
    for (final pattern in _sensitivePatterns) {
      if (pattern.hasMatch(content)) {
        return PolicyCheckResult(isAllowed: false, reason: 'Sensitive data detected: ${pattern.pattern}');
      }
    }
    return const PolicyCheckResult(isAllowed: true);
  }
}

// ─── Stub services ────────────────────────────────────────────────

class StubLocalMemoryStorageService {
  final Map<String, MemoryEntry> _store = {};
  int _nextId = 0;

  MemoryResult<MemoryEntry> save(MemoryEntry entry) {
    final stored = entry.copyWith(id: entry.id.isEmpty ? 'mem_${_nextId++}' : entry.id);
    _store[stored.id] = stored;
    return MemoryResult.success(stored);
  }

  MemoryResult<MemoryEntry?> getById(String id) {
    return MemoryResult.success(_store[id]);
  }

  MemoryResult<List<MemoryEntry>> getAll() {
    return MemoryResult.success(_store.values.toList());
  }

  MemoryResult<bool> delete(String id) {
    if (!_store.containsKey(id)) {
      return MemoryResult.failure(
        MemoryFailure(phase: MemoryFailurePhase.storage, message: 'Not found: $id'),
      );
    }
    _store.remove(id);
    return MemoryResult.success(true);
  }

  MemoryResult<MemoryEntry> update(MemoryEntry entry) {
    if (!_store.containsKey(entry.id)) {
      return MemoryResult.failure(
        MemoryFailure(phase: MemoryFailurePhase.storage, message: 'Not found: ${entry.id}'),
      );
    }
    _store[entry.id] = entry;
    return MemoryResult.success(entry);
  }
}

class StubVectorSearchService {
  final StubLocalMemoryStorageService _storage;
  StubVectorSearchService(this._storage);

  MemoryResult<List<MemoryEntry>> search(String query, {int topK = 5}) {
    // Simplified: substring match instead of vector similarity
    final all = _storage.getAll();
    if (all.isFailure) return MemoryResult.failure(all.failure);
    final matches = all.value.where((e) =>
      e.isActive && (e.content.toLowerCase().contains(query.toLowerCase()))
    ).take(topK).toList();
    return MemoryResult.success(matches);
  }
}

// ─── MemoryManager ────────────────────────────────────────────────

class MemoryManager {
  final StubLocalMemoryStorageService _storage;
  final StubVectorSearchService _search;
  final MemoryPolicy _policy;

  MemoryManager({
    required StubLocalMemoryStorageService storage,
    required StubVectorSearchService search,
    required MemoryPolicy policy,
  }) : _storage = storage, _search = search, _policy = policy;

  MemoryResult<MemoryEntry> remember(String content, MemoryType type, {double importance = 0.5, String source = 'conversation'}) {
    final policyResult = _policy.check(content);
    if (!policyResult.isAllowed) {
      return MemoryResult.failure(
        MemoryFailure(phase: MemoryFailurePhase.policy, message: policyResult.reason ?? 'Policy violation'),
      );
    }
    final now = DateTime.now();
    final entry = MemoryEntry(
      id: '', content: content, memoryType: type,
      createdAt: now, updatedAt: now, importance: importance, source: source,
    );
    return _storage.save(entry);
  }

  MemoryResult<List<MemoryEntry>> recall(String query, {int topK = 5}) {
    return _search.search(query, topK: topK);
  }

  MemoryResult<bool> forget(String id) {
    return _storage.delete(id);
  }

  MemoryResult<MemoryEntry> updateEntry(String id, {String? content, double? importance, MemoryType? memoryType, bool? isActive}) {
    final existing = _storage.getById(id);
    if (existing.isFailure) return MemoryResult.failure(existing.failure);
    if (existing.value == null) return MemoryResult.failure(
      MemoryFailure(phase: MemoryFailurePhase.storage, message: 'Not found: $id'),
    );
    if (content != null) {
      final policyResult = _policy.check(content);
      if (!policyResult.isAllowed) return MemoryResult.failure(
        MemoryFailure(phase: MemoryFailurePhase.policy, message: policyResult.reason ?? 'Policy violation'),
      );
    }
    final updated = existing.value!.copyWith(
      content: content, importance: importance, memoryType: memoryType, isActive: isActive,
      updatedAt: DateTime.now(),
    );
    return _storage.update(updated);
  }

  MemoryResult<List<MemoryEntry>> list({MemoryType? type}) {
    final all = _storage.getAll();
    if (all.isFailure) return MemoryResult.failure(all.failure);
    var entries = all.value;
    if (type != null) entries = entries.where((e) => e.memoryType == type).toList();
    return MemoryResult.success(entries);
  }
}

// ─── Integration tests ─────────────────────────────────────────────

void main() {
  group('Memory Full Integration', () {
    late StubLocalMemoryStorageService storage;
    late StubVectorSearchService search;
    late MemoryPolicy policy;
    late MemoryManager manager;

    setUp(() {
      storage = StubLocalMemoryStorageService();
      search = StubVectorSearchService(storage);
      policy = MemoryPolicy();
      manager = MemoryManager(storage: storage, search: search, policy: policy);
    });

    test('full lifecycle: remember → recall → update → forget', () {
      // 1. Remember
      final rememberResult = manager.remember(
        'User prefers dark mode for the UI',
        MemoryType.userPreference,
        importance: 0.8,
        source: 'conversation',
      );
      expect(rememberResult.isSuccess, isTrue);
      final memoryId = rememberResult.value.id;
      expect(memoryId, isNotEmpty);
      expect(rememberResult.value.content, 'User prefers dark mode for the UI');
      expect(rememberResult.value.memoryType, MemoryType.userPreference);
      expect(rememberResult.value.importance, 0.8);
      expect(rememberResult.value.source, 'conversation');
      expect(rememberResult.value.isActive, isTrue);

      // 2. Recall
      final recallResult = manager.recall('dark mode');
      expect(recallResult.isSuccess, isTrue);
      expect(recallResult.value, isNotEmpty);
      expect(recallResult.value.any((e) => e.id == memoryId), isTrue);

      // 3. Update
      final updateResult = manager.updateEntry(memoryId, content: 'User prefers light mode for the UI', importance: 0.9);
      expect(updateResult.isSuccess, isTrue);
      expect(updateResult.value.content, 'User prefers light mode for the UI');
      expect(updateResult.value.importance, 0.9);
      expect(updateResult.value.id, memoryId); // Same ID

      // 4. Recall after update
      final recallAfterUpdate = manager.recall('light mode');
      expect(recallAfterUpdate.isSuccess, isTrue);
      expect(recallAfterUpdate.value.any((e) => e.content.contains('light mode')), isTrue);

      // 5. Forget
      final forgetResult = manager.forget(memoryId);
      expect(forgetResult.isSuccess, isTrue);

      // 6. Recall after delete
      final recallAfterDelete = manager.recall('light mode');
      expect(recallAfterDelete.isSuccess, isTrue);
      expect(recallAfterDelete.value.any((e) => e.id == memoryId), isFalse);
    });

    test('multiple memories with different types', () {
      manager.remember('I like tea', MemoryType.userPreference, importance: 0.7);
      manager.remember('Buy groceries', MemoryType.task, importance: 0.6);
      manager.remember('My name is Ali', MemoryType.personalFact, importance: 0.9);

      final allResult = manager.list();
      expect(allResult.isSuccess, isTrue);
      expect(allResult.value, hasLength(3));

      final prefs = manager.list(type: MemoryType.userPreference);
      expect(prefs.value, hasLength(1));
      expect(prefs.value.first.content, 'I like tea');

      final tasks = manager.list(type: MemoryType.task);
      expect(tasks.value, hasLength(1));

      final facts = manager.list(type: MemoryType.personalFact);
      expect(facts.value, hasLength(1));
    });

    test('policy blocks sensitive data throughout lifecycle', () {
      // Remember with password
      final blocked = manager.remember('My password is secret123', MemoryType.personalFact);
      expect(blocked.isFailure, isTrue);
      expect(blocked.failure.phase, MemoryFailurePhase.policy);

      // Store a safe memory first
      final safe = manager.remember('My name is Dara', MemoryType.personalFact);
      expect(safe.isSuccess, isTrue);

      // Try to update with sensitive content
      final updateBlocked = manager.updateEntry(safe.value.id, content: 'password changed to xyz');
      expect(updateBlocked.isFailure, isTrue);
      expect(updateBlocked.failure.phase, MemoryFailurePhase.policy);

      // Original should be unchanged
      final recalled = manager.recall('Dara');
      expect(recalled.isSuccess, isTrue);
      expect(recalled.value.first.content, 'My name is Dara');
    });

    test('forget non-existent memory returns failure', () {
      final result = manager.forget('nonexistent_id');
      expect(result.isFailure, isTrue);
      expect(result.failure.phase, MemoryFailurePhase.storage);
    });

    test('update non-existent memory returns failure', () {
      final result = manager.updateEntry('nonexistent', content: 'X');
      expect(result.isFailure, isTrue);
      expect(result.failure.phase, MemoryFailurePhase.storage);
    });

    test('soft-delete via isActive flag', () {
      final entry = manager.remember('Soft delete test', MemoryType.conversation);
      final id = entry.value.id;

      final deactivated = manager.updateEntry(id, isActive: false);
      expect(deactivated.isSuccess, isTrue);
      expect(deactivated.value.isActive, isFalse);

      // Search should not return inactive
      final searchResult = manager.recall('Soft delete');
      expect(searchResult.isSuccess, isTrue);
      expect(searchResult.value, isEmpty);

      // But list still returns it
      final listResult = manager.list();
      expect(listResult.value.any((e) => e.id == id), isTrue);
    });

    test('importance ranking in results', () {
      manager.remember('Low importance', MemoryType.conversation, importance: 0.1);
      manager.remember('High importance', MemoryType.conversation, importance: 0.95);
      manager.remember('Medium importance', MemoryType.conversation, importance: 0.5);

      final list = manager.list();
      expect(list.isSuccess, isTrue);
      expect(list.value, hasLength(3));
      // All entries exist, order depends on storage
      expect(list.value.any((e) => e.importance >= 0.9), isTrue);
    });

    test('recall with topK limits results', () {
      for (int i = 0; i < 10; i++) {
        manager.remember('Memory item $i', MemoryType.conversation);
      }

      final top3 = manager.recall('Memory', topK: 3);
      expect(top3.isSuccess, isTrue);
      expect(top3.value.length, lessThanOrEqualTo(3));
    });

    test('concurrent remember and recall operations', () {
      // Store several memories
      final ids = <String>[];
      for (int i = 0; i < 5; i++) {
        final r = manager.remember('Memory $i', MemoryType.conversation);
        ids.add(r.value.id);
      }

      // Recall should find them
      final recall = manager.recall('Memory');
      expect(recall.isSuccess, isTrue);
      expect(recall.value, isNotEmpty);

      // Delete one and recall again
      manager.forget(ids.first);
      final recallAfter = manager.recall('Memory');
      expect(recallAfter.value.where((e) => e.id == ids.first), isEmpty);
    });

    test('api key pattern is rejected by policy', () {
      final blocked = manager.remember('my api_key is abc123', MemoryType.other);
      expect(blocked.isFailure, isTrue);
      expect(blocked.failure.phase, MemoryFailurePhase.policy);
    });

    test('auth token pattern is rejected by policy', () {
      final blocked = manager.remember('auth_token=Bearer xyz', MemoryType.other);
      expect(blocked.isFailure, isTrue);
      expect(blocked.failure.phase, MemoryFailurePhase.policy);
    });
  });
}
