/// agent_memory_integration.dart
/// AURA Assistant – Step 17: Semantic Memory
///
/// Integration hooks between semantic memory and the agent context.
/// Injects relevant memories into AgentContext via addMessage()/withHistory(),
/// and captures memories from agent conversations.
///
/// IMPORTANT: AgentContext uses addMessage() and withHistory() —
/// NOT conversationHistory in update().
///
/// Kurdish-first, local-first, privacy-conscious.
library;

import '../domain/models/memory_entry.dart';
import '../domain/models/memory_failure.dart';
import '../domain/models/memory_type.dart';
import 'memory_manager.dart';
import 'memory_policy.dart';
import '../../../core/errors/result.dart';

/// Represents the agent context for integration purposes.
///
/// This is a simplified view of the agent context — the actual
/// AgentContext class lives in the assistant_integration feature.
/// We only depend on the methods we need: [addMessage] and [withHistory].
abstract class AgentContextView {
  /// Add a message to the conversation context.
  void addMessage({required String role, required String content});

  /// Create a new context with an extended history.
  AgentContextView withHistory(List<MapEntry<String, String>> history);

  /// The current conversation history.
  List<MapEntry<String, String>> get history;
}

/// Integration layer between semantic memory and the agent.
///
/// Responsible for:
/// 1. Injecting relevant memories into the agent context before
///    processing a user query (context enrichment).
/// 2. Extracting memorable information from conversations
///    after the agent responds (memory capture).
///
/// This class does NOT own the agent context — it receives it
/// as a parameter and modifies it through the public API.
class AgentMemoryIntegration {
  final MemoryManager _memoryManager;
  final MemoryPolicy _policy;

  /// Maximum number of memories to inject into context.
  final int maxContextMemories;

  /// Minimum similarity score for context injection.
  final double minContextScore;

  /// Create an integration with the given memory manager.
  AgentMemoryIntegration({
    required MemoryManager memoryManager,
    MemoryPolicy? policy,
    this.maxContextMemories = 5,
    this.minContextScore = 0.4,
  })  : _memoryManager = memoryManager,
        _policy = policy ?? MemoryPolicy();

  /// Enrich the agent context with relevant memories before processing.
  ///
  /// Searches for memories relevant to [userQuery] and injects them
  /// as system messages into the agent context via [addMessage].
  ///
  /// Returns the enriched context or a failure.
  Future<MemoryResult<AgentContextView>> enrichContext({
    required AgentContextView context,
    required String userQuery,
  }) async {
    try {
      // Recall relevant memories.
      final recallResult = await _memoryManager.recall(
        query: userQuery,
        limit: maxContextMemories,
        minScore: minContextScore,
      );

      if (recallResult.isError) {
        // Non-fatal: enrichment failure should not block the agent.
        // Return the original context unmodified.
        return Result.success(context);
      }

      final memories = recallResult.value!;
      if (memories.isEmpty) {
        return Result.success(context);
      }

      // Format memories as a system context message.
      final memoryContext = _formatMemoryContext(memories);

      // Inject via addMessage.
      context.addMessage(
        role: 'system',
        content: memoryContext,
      );

      return Result.success(context);
    } catch (e) {
      return Result.error(MemoryFailure.integration(
        detail: 'Context enrichment failed',
        cause: e,
      ));
    }
  }

  /// Extract and store memorable information from a conversation exchange.
  ///
  /// Analyzes the conversation history and extracts facts, preferences,
  /// instructions, etc. that should be remembered for future interactions.
  ///
  /// Returns the number of new memories created, or a failure.
  Future<MemoryResult<int>> captureFromConversation({
    required List<MapEntry<String, String>> history,
  }) async {
    try {
      int captured = 0;

      // Look at user messages for potential memories.
      for (final entry in history) {
        if (entry.key != 'user') continue;
        final content = entry.value;

        // Skip short messages unlikely to contain memorable info.
        if (content.length < 10) continue;

        // Check policy.
        if (!_policy.isAllowed(content)) continue;

        // Detect memory type from content.
        final type = _detectMemoryType(content);

        // Attempt to remember.
        final result = await _memoryManager.remember(
          content: content,
          type: type,
          source: 'conversation',
        );

        if (result.isSuccess) {
          captured++;
        }
      }

      return Result.success(captured);
    } catch (e) {
      return Result.error(MemoryFailure.integration(
        detail: 'Conversation capture failed',
        cause: e,
      ));
    }
  }

  // ─── Private helpers ──────────────────────────────────────────────

  /// Format memories into a context string for agent injection.
  String _formatMemoryContext(List<MemoryEntry> memories) {
    final buffer = StringBuffer();
    buffer.writeln('[Semantic Memory Context]');
    buffer.writeln(
      'The following information was recalled from the user\'s semantic memory:',
    );

    for (var i = 0; i < memories.length; i++) {
      final m = memories[i];
      buffer.writeln('  ${i + 1}. [${m.memoryType.name}] ${m.content}');
    }

    buffer.writeln(
      'Use this context to provide more personalised responses.',
    );
    return buffer.toString();
  }

  /// Detect the most likely [MemoryType] from content heuristics.
  MemoryType _detectMemoryType(String content) {
    final lower = content.toLowerCase();

    if (lower.contains('prefer') || lower.contains('like') ||
        lower.contains('dislike') || lower.contains('want')) {
      return MemoryType.userPreference;
    }
    if (lower.contains('my name is') || lower.contains('i am ') ||
        lower.contains('i live')) {
      return MemoryType.personalFact;
    }
    if (lower.contains('remind') || lower.contains('todo') ||
        lower.contains('task') || lower.contains('remember to')) {
      return MemoryType.task;
    }
    if (lower.contains('always') || lower.contains('never') ||
        lower.contains('from now on')) {
      return MemoryType.instruction;
    }
    if (lower.contains('project') || lower.contains('working on')) {
      return MemoryType.project;
    }

    return MemoryType.conversation;
  }
}
