/// agent_memory_integration_test.dart
/// Structural tests for AgentMemoryIntegration.
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
  final String id; final String content; final MemoryType memoryType;
  final DateTime createdAt; final DateTime updatedAt; final double importance;
  final String source; final List<double>? embedding; final bool isActive;
  const MemoryEntry({
    required this.id, required this.content, required this.memoryType,
    required this.createdAt, required this.updatedAt,
    this.importance = 0.5, this.source = 'unknown', this.embedding, this.isActive = true,
  });
}

/// Minimal AgentContext mirror.
class AgentMessage {
  final String role;
  final String content;
  const AgentMessage({required this.role, required this.content});
}

class AgentContext {
  final List<AgentMessage> history;
  AgentContext({this.history = const []});

  AgentContext addMessage(String role, String content) =>
      AgentContext(history: [...history, AgentMessage(role: role, content: content)]);
}

/// Stub MemoryManager mirror.
class StubMemoryManager {
  final List<MemoryEntry> _entries = [];

  MemoryResult<MemoryEntry> remember(String content, MemoryType type, {double importance = 0.5, String source = 'unknown'}) {
    final now = DateTime.now();
    final entry = MemoryEntry(
      id: 'mem_${_entries.length}', content: content, memoryType: type,
      createdAt: now, updatedAt: now, importance: importance, source: source,
    );
    _entries.add(entry);
    return MemoryResult.success(entry);
  }

  MemoryResult<List<MemoryEntry>> recall(String query, {int topK = 5}) {
    // Simplified: return all entries
    return MemoryResult.success(_entries);
  }
}

/// Mirror of AgentMemoryIntegration.
class AgentMemoryIntegration {
  final StubMemoryManager _memoryManager;

  AgentMemoryIntegration({required StubMemoryManager memoryManager})
    : _memoryManager = memoryManager;

  AgentContext enrichContext(AgentContext context, String query) {
    final memoryResult = _memoryManager.recall(query);
    if (memoryResult.isFailure || memoryResult.value.isEmpty) return context;

    final memorySummary = memoryResult.value
        .map((e) => '[${e.memoryType.name}] ${e.content}')
        .join('\n');
    return context.addMessage('system', 'Relevant memories:\n$memorySummary');
  }

  MemoryResult<MemoryEntry> captureFromConversation(String content, MemoryType type, {double importance = 0.5, String source = 'conversation'}) {
    return _memoryManager.remember(content, type, importance: importance, source: source);
  }

  MemoryType detectMemoryType(String content) {
    final lower = content.toLowerCase();
    if (lower.contains('prefer') || lower.contains('like') || lower.contains('dislike') || lower.contains('favorite')) {
      return MemoryType.userPreference;
    }
    if (lower.contains('my name') || lower.contains('i am ') || lower.contains('i live') || lower.contains('i work')) {
      return MemoryType.personalFact;
    }
    if (lower.contains('todo') || lower.contains('task') || lower.contains('remind') || lower.contains('need to')) {
      return MemoryType.task;
    }
    if (lower.contains('project') || lower.contains('working on')) {
      return MemoryType.project;
    }
    if (lower.contains('location') || lower.contains('place') || lower.contains('where')) {
      return MemoryType.location;
    }
    return MemoryType.conversation;
  }
}

void main() {
  group('AgentMemoryIntegration', () {
    late StubMemoryManager manager;
    late AgentMemoryIntegration integration;

    setUp(() {
      manager = StubMemoryManager();
      integration = AgentMemoryIntegration(memoryManager: manager);
    });

    group('enrichContext', () {
      test('adds memories to agent context when memories exist', () {
        manager.remember('User prefers dark mode', MemoryType.userPreference);
        manager.remember('User lives in Erbil', MemoryType.personalFact);

        final baseContext = AgentContext();
        final enriched = integration.enrichContext(baseContext, 'preferences');

        expect(enriched.history, hasLength(1));
        expect(enriched.history.first.role, 'system');
        expect(enriched.history.first.content, contains('Relevant memories'));
        expect(enriched.history.first.content, contains('dark mode'));
        expect(enriched.history.first.content, contains('Erbil'));
      });

      test('returns unchanged context when no memories', () {
        final baseContext = AgentContext();
        final enriched = integration.enrichContext(baseContext, 'nothing');

        expect(enriched.history, hasLength(0));
      });

      test('preserves existing context history', () {
        manager.remember('Test memory', MemoryType.other);
        final baseContext = AgentContext()
            .addMessage('user', 'Hello')
            .addMessage('assistant', 'Hi there');

        final enriched = integration.enrichContext(baseContext, 'test');
        expect(enriched.history, hasLength(3)); // 2 original + 1 memory
        expect(enriched.history.first.role, 'user');
        expect(enriched.history[1].role, 'assistant');
        expect(enriched.history.last.role, 'system');
      });
    });

    group('captureFromConversation', () {
      test('stores content from conversation', () {
        final result = integration.captureFromConversation(
          'User likes coffee', MemoryType.userPreference,
          source: 'conversation',
        );
        expect(result.isSuccess, isTrue);
        expect(result.value.content, 'User likes coffee');
        expect(result.value.source, 'conversation');
      });

      test('uses specified memory type', () {
        final result = integration.captureFromConversation(
          'Task: buy milk', MemoryType.task,
        );
        expect(result.value.memoryType, MemoryType.task);
      });

      test('defaults source to conversation', () {
        final result = integration.captureFromConversation(
          'Something', MemoryType.conversation,
        );
        expect(result.value.source, 'conversation');
      });
    });

    group('detectMemoryType', () {
      test('detects userPreference from preference keywords', () {
        expect(integration.detectMemoryType('I prefer tea over coffee'), MemoryType.userPreference);
        expect(integration.detectMemoryType('I like python'), MemoryType.userPreference);
        expect(integration.detectMemoryType('My favorite color is blue'), MemoryType.userPreference);
        expect(integration.detectMemoryType('I dislike loud noises'), MemoryType.userPreference);
      });

      test('detects personalFact from personal keywords', () {
        expect(integration.detectMemoryType('My name is Ali'), MemoryType.personalFact);
        expect(integration.detectMemoryType('I am a developer'), MemoryType.personalFact);
        expect(integration.detectMemoryType('I live in Sulaymaniyah'), MemoryType.personalFact);
        expect(integration.detectMemoryType('I work at a company'), MemoryType.personalFact);
      });

      test('detects task from task keywords', () {
        expect(integration.detectMemoryType('Todo: fix bug'), MemoryType.task);
        expect(integration.detectMemoryType('Task: write report'), MemoryType.task);
        expect(integration.detectMemoryType('Remind me to call mom'), MemoryType.task);
        expect(integration.detectMemoryType('I need to buy groceries'), MemoryType.task);
      });

      test('detects project from project keywords', () {
        expect(integration.detectMemoryType('Project AURA is great'), MemoryType.project);
        expect(integration.detectMemoryType('I am working on a new feature'), MemoryType.project);
      });

      test('detects location from location keywords', () {
        expect(integration.detectMemoryType('Location: Erbil'), MemoryType.location);
        expect(integration.detectMemoryType('Nice place for lunch'), MemoryType.location);
        expect(integration.detectMemoryType('Where is the office?'), MemoryType.location);
      });

      test('defaults to conversation for unknown content', () {
        expect(integration.detectMemoryType('The weather is nice today'), MemoryType.conversation);
        expect(integration.detectMemoryType('Random statement'), MemoryType.conversation);
      });

      test('detection is case insensitive', () {
        expect(integration.detectMemoryType('I PREFER tea'), MemoryType.userPreference);
        expect(integration.detectMemoryType('MY NAME IS ALI'), MemoryType.personalFact);
      });
    });
  });
}
