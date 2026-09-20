/// Step 23 — Memory Adapter
///
/// Thin adapter bridging the orchestration [MemoryRepository] to the
/// canonical Step 17 / Phase 1 Semantic Memory subsystem via
/// [MemoryContextProvider] (which itself delegates to [MemoryManager.recall]).
///
/// This adapter creates NO competing memory store. It reuses the exact same
/// [MemoryContextProvider] instance wired by `memoryContextProvider`, which
/// is built on the same [MemoryManager] that Phase 1's AgentEngine
/// enrichment/capture hooks use. It therefore does NOT bypass the existing
/// memory architecture — it is simply an additional read-only consumer used
/// by the orchestrator's MEMORY LOOKUP phase.
///
/// memoryContext is String? (per Step 17 contract): an empty recall result
/// maps to null so the orchestrator degrades safely.
///
/// FAIL-CLOSED: any memory failure → null (safe degradation; does NOT block
/// orchestration).

import '../../../semantic_memory/application/providers/memory_context_provider.dart';
import '../../domain/repositories/memory_repository.dart';

class MemoryAdapter implements MemoryRepository {
  /// Canonical semantic-memory context builder (Phase 1).
  final MemoryContextProvider _contextProvider;

  /// Wire the adapter to the real [MemoryContextProvider] (injected).
  MemoryAdapter(this._contextProvider);

  @override
  Future<String?> lookup(String userRequest, String locale) async {
    try {
      // buildContext() runs the real semantic recall pipeline and returns
      // a formatted context string, or '' when nothing relevant is found
      // or recall fails (it already swallows recall errors internally).
      final context = await _contextProvider.buildContext(userQuery: userRequest);
      if (context.isEmpty) return null; // no relevant memory → degrade safely
      return context;
    } catch (_) {
      return null; // FAIL-CLOSED: memory failure → null
    }
  }

  @override
  Future<bool> isAvailable() async {
    // Semantic memory is local-first, so the subsystem itself is always
    // reachable. Any transient failure surfaces through lookup() returning
    // null (safe degradation) rather than through this availability gate,
    // matching the interface contract that null context never blocks
    // orchestration.
    return true;
  }
}
