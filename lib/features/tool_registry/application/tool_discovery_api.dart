/// tool_discovery_api.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Public API for tool discovery. Provides search, filtering, and
/// categorization of available tools.
///
/// This is the Presentation-friendly API that the UI layer consumes.
/// It wraps the domain [ToolRegistryService] with richer return types
/// and discovery-specific logic.
library;

import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/models.dart';

/// A single discovered tool with its allowlist status.
class DiscoveredTool {
  final ToolDefinition definition;
  final bool isAllowed;
  final bool canExecute;

  const DiscoveredTool({
    required this.definition,
    required this.isAllowed,
    required this.canExecute,
  });

  @override
  String toString() =>
      'DiscoveredTool(${definition.toolId}, allowed: $isAllowed, '
      'canExecute: $canExecute)';
}

/// Result of a tool discovery query.
class DiscoveryResult {
  final List<DiscoveredTool> tools;
  final String query;
  final int totalCount;
  final bool hasMore;

  const DiscoveryResult({
    required this.tools,
    required this.query,
    required this.totalCount,
    this.hasMore = false,
  });

  @override
  String toString() =>
      'DiscoveryResult(query: "$query", found: ${tools.length}/$totalCount)';
}

/// Abstract discovery API for the tool registry.
///
/// Application-layer service that provides discovery capabilities
/// for the Presentation layer.
abstract class ToolDiscoveryApi {
  /// Search for tools matching [query].
  ///
  /// Searches across tool name, description, tags, and category.
  /// Results include allowlist and execution status.
  ToolResult<DiscoveryResult> search(String query);

  /// Get all tools in a given [category].
  ///
  /// Results include allowlist and execution status.
  ToolResult<DiscoveryResult> byCategory(ToolCategory category);

  /// Get all currently available (enabled + allowed) tools.
  ToolResult<DiscoveryResult> available();

  /// Get tools that require user attention (disabled, not allowed, etc.).
  ToolResult<DiscoveryResult> needsAttention();

  /// Get a specific tool's discovery info.
  ToolResult<DiscoveredTool> getTool(String toolId);

  /// Get the list of all categories that have at least one tool.
  List<ToolCategory> activeCategories();
}
