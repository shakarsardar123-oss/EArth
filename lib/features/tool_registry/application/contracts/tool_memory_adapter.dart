/// tool_memory_adapter.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Adapter that bridges Step 17's MemoryManager into the
/// Tool Registry's execution pipeline.
///
/// Used for:
/// - Storing/retrieving tool execution history
/// - Remembering user preferences for tool allowlisting
/// - Persisting tool registry state across sessions
library;

import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/models.dart';

/// Result of a memory operation related to tools.
class ToolMemoryResult {
  final bool success;
  final String? data;
  final String? error;

  const ToolMemoryResult({
    required this.success,
    this.data,
    this.error,
  });

  factory ToolMemoryResult.ok({String? data}) =>
      ToolMemoryResult(success: true, data: data);

  factory ToolMemoryResult.failed({String? error}) =>
      ToolMemoryResult(success: false, error: error ?? 'Memory operation failed');
}

/// Abstract interface for the memory adapter.
///
/// Bridges Step 17's MemoryManager so the tool
/// registry does not depend on it directly.
abstract class ToolMemoryAdapter {
  /// Store a tool-related memory.
  ///
  /// [key] – memory key (e.g., 'tool_execution_history:voice_call').
  /// [value] – the data to store (JSON string).
  /// [tags] – optional tags for categorization.
  Future<ToolMemoryResult> store({
    required String key,
    required String value,
    List<String>? tags,
  });

  /// Recall a tool-related memory.
  ///
  /// [key] – memory key to recall.
  /// Returns the stored value, or null if not found.
  Future<ToolMemoryResult> recall({required String key});

  /// Search tool-related memories.
  ///
  /// [query] – search query.
  /// [tags] – filter by tags.
  /// Returns matching memory entries as JSON string.
  Future<ToolMemoryResult> search({
    required String query,
    List<String>? tags,
  });

  /// Delete a tool-related memory.
  Future<ToolMemoryResult> forget({required String key});

  /// Whether the memory service is currently available.
  bool get isAvailable;
}

