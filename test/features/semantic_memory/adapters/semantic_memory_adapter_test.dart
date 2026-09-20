/// semantic_memory_adapter_test.dart
/// Structural tests for SemanticMemoryAdapter.
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
  PolicyCheckResult check(String content) {
    if (content.toLowerCase().contains('password')) return const PolicyCheckResult(isAllowed: false, reason: 'password');
    return const PolicyCheckResult(isAllowed: true);
  }
}

/// Stub MemoryManager.
class StubMemoryManager {
  final Map<String, MemoryEntry> _entries = {};
  int _nextId = 0;

  MemoryResult<MemoryEntry> remember(String content, MemoryType type, {double importance = 0.5, String source = 'unknown'}) {
    final now = DateTime.now();
    final entry = MemoryEntry(
      id: 'mem_${_nextId++}', content: content, memoryType: type,
      createdAt: now, updatedAt: now, importance: importance, source: source,
    );
    _entries[entry.id] = entry;
    return MemoryResult.success(entry);
  }

  MemoryResult<List<MemoryEntry>> recall(String query, {int topK = 5}) {
    return MemoryResult.success(_entries.values.toList());
  }

  MemoryResult<bool> forget(String id) {
    if (!_entries.containsKey(id)) return MemoryResult.failure(
      MemoryFailure(phase: MemoryFailurePhase.storage, message: 'Not found'),
    );
    _entries.remove(id);
    return MemoryResult.success(true);
  }

  MemoryResult<MemoryEntry> updateEntry(String id, {String? content, double? importance, MemoryType? memoryType, bool? isActive}) {
    if (!_entries.containsKey(id)) return MemoryResult.failure(
      MemoryFailure(phase: MemoryFailurePhase.storage, message: 'Not found'),
    );
    final existing = _entries[id]!;
    final updated = existing.copyWith(
      content: content, importance: importance, memoryType: memoryType, isActive: isActive,
    );
    _entries[id] = updated;
    return MemoryResult.success(updated);
  }

  MemoryResult<List<MemoryEntry>> list({MemoryType? type}) {
    var entries = _entries.values.toList();
    if (type != null) entries = entries.where((e) => e.memoryType == type).toList();
    return MemoryResult.success(entries);
  }
}

// ─── Adapter models mirror ─────────────────────────────────────────

class MemoryToolResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  const MemoryToolResult({required this.success, required this.message, this.data});
}

class MemoryToolParam {
  final String name;
  final String description;
  final bool required;
  final String? defaultValue;
  const MemoryToolParam({required this.name, required this.description, this.required = false, this.defaultValue});
}

class MemoryToolDef {
  final String name;
  final String description;
  final List<MemoryToolParam> parameters;
  const MemoryToolDef({required this.name, required this.description, required this.parameters});
}

/// Mirror of SemanticMemoryAdapter.
class SemanticMemoryAdapter {
  final StubMemoryManager _manager;
  final MemoryPolicy _policy;

  static const rememberTool = MemoryToolDef(
    name: 'memory_remember',
    description: 'Store a memory for later recall',
    parameters: [
      MemoryToolParam(name: 'content', description: 'Content to remember', required: true),
      MemoryToolParam(name: 'type', description: 'Memory type', defaultValue: 'conversation'),
      MemoryToolParam(name: 'importance', description: 'Importance 0-1', defaultValue: '0.5'),
    ],
  );

  static const recallTool = MemoryToolDef(
    name: 'memory_recall',
    description: 'Search and recall memories',
    parameters: [
      MemoryToolParam(name: 'query', description: 'Search query', required: true),
      MemoryToolParam(name: 'topK', description: 'Max results', defaultValue: '5'),
    ],
  );

  static const forgetTool = MemoryToolDef(
    name: 'memory_forget',
    description: 'Remove a memory by ID',
    parameters: [
      MemoryToolParam(name: 'id', description: 'Memory ID to forget', required: true),
    ],
  );

  static const updateTool = MemoryToolDef(
    name: 'memory_update',
    description: 'Update an existing memory',
    parameters: [
      MemoryToolParam(name: 'id', description: 'Memory ID', required: true),
      MemoryToolParam(name: 'content', description: 'New content'),
      MemoryToolParam(name: 'importance', description: 'New importance 0-1'),
    ],
  );

  static const listTool = MemoryToolDef(
    name: 'memory_list',
    description: 'List all memories or filter by type',
    parameters: [
      MemoryToolParam(name: 'type', description: 'Filter by type'),
    ],
  );

  static List<MemoryToolDef> get allTools => [rememberTool, recallTool, forgetTool, updateTool, listTool];

  SemanticMemoryAdapter({required StubMemoryManager manager, required MemoryPolicy policy})
    : _manager = manager, _policy = policy;

  MemoryToolResult execute(String toolName, Map<String, dynamic> params) {
    switch (toolName) {
      case 'memory_remember':
        final content = params['content'] as String?;
        if (content == null || content.isEmpty) return const MemoryToolResult(success: false, message: 'Content required');
        final policyResult = _policy.check(content);
        if (!policyResult.isAllowed) return MemoryToolResult(success: false, message: 'Policy violation: ${policyResult.reason}');
        final type = _parseType(params['type'] as String?);
        final importance = double.tryParse(params['importance']?.toString() ?? '0.5') ?? 0.5;
        final result = _manager.remember(content, type, importance: importance);
        return result.isSuccess
          ? MemoryToolResult(success: true, message: 'Remembered: ${result.value.id}', data: {'id': result.value.id})
          : MemoryToolResult(success: false, message: result.failure.message);

      case 'memory_recall':
        final query = params['query'] as String?;
        if (query == null || query.isEmpty) return const MemoryToolResult(success: false, message: 'Query required');
        final topK = int.tryParse(params['topK']?.toString() ?? '5') ?? 5;
        final result = _manager.recall(query, topK: topK);
        return result.isSuccess
          ? MemoryToolResult(success: true, message: 'Found ${result.value.length} memories', data: {'memories': result.value.map((e) => {'id': e.id, 'content': e.content}).toList()})
          : MemoryToolResult(success: false, message: result.failure.message);

      case 'memory_forget':
        final id = params['id'] as String?;
        if (id == null || id.isEmpty) return const MemoryToolResult(success: false, message: 'ID required');
        final result = _manager.forget(id);
        return result.isSuccess
          ? MemoryToolResult(success: true, message: 'Forgot: $id')
          : MemoryToolResult(success: false, message: result.failure.message);

      case 'memory_update':
        final id = params['id'] as String?;
        if (id == null || id.isEmpty) return const MemoryToolResult(success: false, message: 'ID required');
        final content = params['content'] as String?;
        final importance = params['importance'] != null ? double.tryParse(params['importance'].toString()) : null;
        final type = params['type'] != null ? _parseType(params['type'] as String?) : null;
        final result = _manager.updateEntry(id, content: content, importance: importance, memoryType: type);
        return result.isSuccess
          ? MemoryToolResult(success: true, message: 'Updated: $id', data: {'id': result.value.id})
          : MemoryToolResult(success: false, message: result.failure.message);

      case 'memory_list':
        final type = params['type'] != null ? _parseType(params['type'] as String?) : null;
        final result = _manager.list(type: type);
        return result.isSuccess
          ? MemoryToolResult(success: true, message: '${result.value.length} memories', data: {'memories': result.value.map((e) => {'id': e.id, 'content': e.content}).toList()})
          : MemoryToolResult(success: false, message: result.failure.message);

      default:
        return MemoryToolResult(success: false, message: 'Unknown tool: $toolName');
    }
  }

  MemoryType _parseType(String? type) {
    if (type == null) return MemoryType.conversation;
    return MemoryType.values.firstWhere(
      (t) => t.name == type,
      orElse: () => MemoryType.conversation,
    );
  }
}

void main() {
  group('SemanticMemoryAdapter', () {
    late StubMemoryManager manager;
    late MemoryPolicy policy;
    late SemanticMemoryAdapter adapter;

    setUp(() {
      manager = StubMemoryManager();
      policy = MemoryPolicy();
      adapter = SemanticMemoryAdapter(manager: manager, policy: policy);
    });

    group('tool definitions', () {
      test('has exactly 5 tools', () {
        expect(SemanticMemoryAdapter.allTools, hasLength(5));
      });

      test('tool names are correct', () {
        final names = SemanticMemoryAdapter.allTools.map((t) => t.name).toList();
        expect(names, containsAll([
          'memory_remember',
          'memory_recall',
          'memory_forget',
          'memory_update',
          'memory_list',
        ]));
      });

      test('remember tool has required content param', () {
        final contentParam = SemanticMemoryAdapter.rememberTool.parameters.firstWhere(
          (p) => p.name == 'content',
        );
        expect(contentParam.required, isTrue);
      });

      test('recall tool has required query param', () {
        final queryParam = SemanticMemoryAdapter.recallTool.parameters.firstWhere(
          (p) => p.name == 'query',
        );
        expect(queryParam.required, isTrue);
      });

      test('forget tool has required id param', () {
        final idParam = SemanticMemoryAdapter.forgetTool.parameters.firstWhere(
          (p) => p.name == 'id',
        );
        expect(idParam.required, isTrue);
      });
    });

    group('execute memory_remember', () {
      test('stores content successfully', () {
        final result = adapter.execute('memory_remember', {
          'content': 'User likes coffee',
          'type': 'userPreference',
        });
        expect(result.success, isTrue);
        expect(result.data, contains('id'));
      });

      test('rejects empty content', () {
        final result = adapter.execute('memory_remember', {'content': ''});
        expect(result.success, isFalse);
      });

      test('rejects missing content', () {
        final result = adapter.execute('memory_remember', {});
        expect(result.success, isFalse);
      });

      test('rejects policy-violating content', () {
        final result = adapter.execute('memory_remember', {
          'content': 'password is secret123',
        });
        expect(result.success, isFalse);
        expect(result.message, contains('Policy'));
      });

      test('parses importance parameter', () {
        final result = adapter.execute('memory_remember', {
          'content': 'Test',
          'importance': '0.9',
        });
        expect(result.success, isTrue);
      });
    });

    group('execute memory_recall', () {
      test('returns memories successfully', () {
        adapter.execute('memory_remember', {'content': 'Hello world'});
        final result = adapter.execute('memory_recall', {'query': 'hello'});
        expect(result.success, isTrue);
        expect(result.data, contains('memories'));
      });

      test('rejects empty query', () {
        final result = adapter.execute('memory_recall', {'query': ''});
        expect(result.success, isFalse);
      });
    });

    group('execute memory_forget', () {
      test('deletes existing memory', () {
        final remembered = adapter.execute('memory_remember', {'content': 'To delete'});
        final id = remembered.data?['id'] as String;
        final result = adapter.execute('memory_forget', {'id': id});
        expect(result.success, isTrue);
        expect(result.message, contains('Forgot'));
      });

      test('fails for missing id', () {
        final result = adapter.execute('memory_forget', {'id': 'nonexistent'});
        expect(result.success, isFalse);
      });

      test('rejects empty id', () {
        final result = adapter.execute('memory_forget', {'id': ''});
        expect(result.success, isFalse);
      });
    });

    group('execute memory_update', () {
      test('updates existing memory', () {
        final remembered = adapter.execute('memory_remember', {'content': 'Original'});
        final id = remembered.data?['id'] as String;
        final result = adapter.execute('memory_update', {'id': id, 'content': 'Updated'});
        expect(result.success, isTrue);
      });

      test('fails for missing id', () {
        final result = adapter.execute('memory_update', {'id': 'nonexistent', 'content': 'X'});
        expect(result.success, isFalse);
      });
    });

    group('execute memory_list', () {
      test('lists all memories', () {
        adapter.execute('memory_remember', {'content': 'A'});
        adapter.execute('memory_remember', {'content': 'B'});
        final result = adapter.execute('memory_list', {});
        expect(result.success, isTrue);
        expect(result.message, contains('2'));
      });

      test('lists memories filtered by type', () {
        adapter.execute('memory_remember', {'content': 'A', 'type': 'userPreference'});
        adapter.execute('memory_remember', {'content': 'B', 'type': 'task'});
        final result = adapter.execute('memory_list', {'type': 'task'});
        expect(result.success, isTrue);
        expect(result.message, contains('1'));
      });
    });

    group('unknown tool', () {
      test('returns failure for unknown tool name', () {
        final result = adapter.execute('memory_unknown', {});
        expect(result.success, isFalse);
        expect(result.message, contains('Unknown'));
      });
    });
  });
}
