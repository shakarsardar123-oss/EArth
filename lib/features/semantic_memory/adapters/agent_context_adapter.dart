/// agent_context_adapter.dart
/// AURA Assistant – Phase 1: Wire Semantic Memory
///
/// Adapter bridging core/agent/AgentContext → AgentContextView.
///
/// PROBLEM (C8): AgentMemoryIntegration.enrichContext() requires
/// AgentContextView (abstract: addMessage{role,content}, withHistory(List<MapEntry>),
/// history getter). But AgentContext (concrete in core/agent/) has
/// addMessage(Map<String,dynamic>), withHistory(List<Map<String,dynamic>>),
/// conversationHistory (List<Map<String,dynamic>>). The interfaces are
/// INCOMPATIBLE — different method signatures and data formats.
///
/// SOLUTION: This adapter implements AgentContextView and wraps AgentContext,
/// translating between the two interfaces:
/// - addMessage(role, content) → AgentContext.addMessage({'role':role,'content':content})
/// - withHistory(List<MapEntry>) → AgentContext.withHistory(List<Map<String,dynamic>>)
/// - history getter → converts conversationHistory to List<MapEntry<String,String>>
///
/// IMPORTANT: Since AgentContext is immutable (all methods return new instances),
/// this adapter holds a mutable reference that gets replaced when the context
/// is enriched. Callers must read the updated context after enrichment.
///
/// Kurdish-first, local-first, privacy-conscious.
library;

import 'package:texo/core/agent/agent_context.dart';
import '../application/agent_memory_integration.dart';

/// Adapter that makes [AgentContext] conform to the [AgentContextView] interface.
///
/// This bridges the interface mismatch (C8) between:
/// - core/agent/AgentContext (concrete, Map<String,dynamic>-based messages)
/// - features/semantic_memory AgentContextView (abstract, role/content-based)
///
/// Usage:
/// ```dart
/// final adapter = AgentContextAdapter(agentContext);
/// await memoryIntegration.enrichContext(context: adapter, userQuery: query);
/// final enrichedContext = adapter.currentContext; // read back updated context
/// ```
class AgentContextAdapter implements AgentContextView {
  AgentContext _context;

  /// Create an adapter wrapping the given [AgentContext].
  AgentContextAdapter(AgentContext context) : _context = context;

  /// The current (possibly enriched) [AgentContext].
  ///
  /// Updated each time [addMessage] or [withHistory] is called.
  /// Read this after enrichment to get the context with memory injected.
  AgentContext get currentContext => _context;

  /// The enriched [relevantMemory] list from the context.
  ///
  /// Updated when [addMessage] injects memory context — also populates
  /// the relevantMemory field so it's available throughout the agent lifecycle.
  List<String> get relevantMemories => _context.relevantMemory;

  @override
  void addMessage({required String role, required String content}) {
    // Translate AgentContextView.addMessage(role, content)
    // → AgentContext.addMessage(Map<String, dynamic>)
    _context = _context.addMessage({'role': role, 'content': content});

    // If this is a memory context injection (system message with memory tag),
    // also populate relevantMemory on the context so it's available
    // throughout the agent lifecycle (C13 fix).
    if (role == 'system' && content.contains('[Semantic Memory Context]')) {
      _context = _context.update(
        relevantMemory: [..._context.relevantMemory, content],
      );
    }
  }

  @override
  AgentContextView withHistory(List<MapEntry<String, String>> history) {
    // Translate List<MapEntry<String,String>> → List<Map<String,dynamic>>
    final mappedHistory = history
        .map((e) => {'role': e.key, 'content': e.value})
        .toList();
    _context = _context.withHistory(mappedHistory);
    // Return self since we implement the interface
    return this;
  }

  @override
  List<MapEntry<String, String>> get history {
    // Translate List<Map<String,dynamic>> → List<MapEntry<String,String>>
    return _context.conversationHistory
        .map((m) {
          final role = (m['role'] ?? 'unknown') as String;
          final content = (m['content'] ?? '') as String;
          return MapEntry(role, content);
        })
        .toList();
  }
}
