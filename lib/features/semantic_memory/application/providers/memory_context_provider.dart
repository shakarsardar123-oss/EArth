/// memory_context_provider.dart
/// AURA Assistant – Phase 1: Wire Semantic Memory
///
/// Provides a formatted context string from recalled semantic memories.
///
/// This is a lower-level utility than [AgentMemoryIntegration] — it
/// produces a raw context string (for injection into prompts) without
/// depending on [AgentContextView]. Use this when you need memory context
/// outside the agent lifecycle (e.g., direct prompt construction).
///
/// For the full enrichment pipeline, prefer [AgentMemoryIntegration.enrichContext]
/// which uses this provider internally and also handles [AgentContextView] bridging.
///
/// Kurdish-first, local-first, privacy-conscious.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../agent_memory_integration.dart';
import '../memory_manager.dart';
import '../memory_policy.dart';
import '../../domain/models/memory_entry.dart';
import '../../domain/models/memory_failure.dart';
import '../../domain/models/memory_type.dart';
import '../memory_providers.dart';
import '../../../../core/errors/result.dart';

/// Provides a formatted context string from recalled semantic memories.
///
/// Usage:
/// ```dart
/// final provider = MemoryContextProvider(memoryManager: manager);
/// final context = await provider.buildContext(userQuery: 'What do I like?');
/// // context = '[Semantic Memory Context]\nThe following information...'
/// ```
class MemoryContextProvider {
  final MemoryManager _memoryManager;
  final MemoryPolicy _policy;

  /// Maximum number of memories to include in the context.
  final int maxMemories;

  /// Minimum similarity score for inclusion.
  final double minScore;

  /// Create a context provider with the given memory manager.
  MemoryContextProvider({
    required MemoryManager memoryManager,
    MemoryPolicy? policy,
    this.maxMemories = 5,
    this.minScore = 0.4,
  })  : _memoryManager = memoryManager,
        _policy = policy ?? MemoryPolicy();

  /// Recall memories relevant to [userQuery] and format them as a
  /// context string suitable for injection into an AI prompt.
  ///
  /// Returns the formatted context string, or an empty string if
  /// no relevant memories are found or if recall fails (non-fatal).
  Future<String> buildContext({
    required String userQuery,
    MemoryType? filterType,
  }) async {
    try {
      final result = await _memoryManager.recall(
        query: userQuery,
        limit: maxMemories,
        minScore: minScore,
        type: filterType,
      );

      if (result.isError) {
        // Non-fatal — return empty context.
        return '';
      }

      final memories = result.value!;
      if (memories.isEmpty) {
        return '';
      }

      return _formatMemoryContext(memories);
    } catch (e) {
      // Never let memory recall failure crash the caller.
      return '';
    }
  }

  /// Recall memories and return them as a list (without formatting).
  ///
  /// Useful when the caller needs raw [MemoryEntry] objects for
  /// custom formatting or further processing.
  Future<List<MemoryEntry>> recallMemories({
    required String userQuery,
    MemoryType? filterType,
  }) async {
    try {
      final result = await _memoryManager.recall(
        query: userQuery,
        limit: maxMemories,
        minScore: minScore,
        type: filterType,
      );

      if (result.isError) return [];
      return result.value!;
    } catch (e) {
      return [];
    }
  }

  // ─── Private helpers ──────────────────────────────────────────────

  /// Format memories into a context string for prompt injection.
  ///
  /// The output format matches [AgentMemoryIntegration._formatMemoryContext]
  /// so that the agent sees a consistent format regardless of which
  /// path (direct provider or integration) was used.
  String _formatMemoryContext(List<MemoryEntry> memories) {
    final buffer = StringBuffer();
    buffer.writeln('[Semantic Memory Context]');
    buffer.writeln(
      "The following information was recalled from the user's semantic memory:",
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
}

// ─── Riverpod provider ──────────────────────────────────────────────

/// Provider for [MemoryContextProvider].
///
/// Delegates to [memoryManagerProvider] for the underlying memory manager.
final memoryContextProvider = Provider<MemoryContextProvider>(
  (ref) => MemoryContextProvider(
    memoryManager: ref.watch(memoryManagerProvider),
    policy: ref.watch(memoryPolicyProvider),
  ),
  name: 'memory_context_provider',
);
