/// tool_registry_service.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Abstract domain service for managing the tool registry and allowlist.
///
/// This is the SINGLE SOURCE OF TRUTH for which tools exist, which are
/// allowed, and how they can be discovered. All tool execution must flow
/// through the [ToolExecutionGate] (application layer), which delegates
/// to this service for registry and allowlist checks.
///
/// FAIL CLOSED: unknown tools are denied, absent allowlist entries = denied.
library;

import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/models.dart';

/// Abstract service for the tool registry.
///
/// Concrete implementations live in the infrastructure layer.
/// This interface follows the same pattern as [AgentSecurityService]
/// (Step 19) and [CentralPermissionService] (Step 16).
abstract class ToolRegistryService {
  /// Register a new tool definition.
  ///
  /// Returns [Result.success] with the registered [ToolDefinition],
  /// or [Result.failure] with a [ToolFailure] if registration fails
  /// (e.g. duplicate toolId, invalid definition).
  ToolResult<ToolDefinition> register(ToolDefinition definition);

  /// Unregister a tool by its [toolId].
  ///
  /// FAIL CLOSED: unregistering a tool also removes its allowlist entry,
  /// ensuring the tool cannot be executed after unregistration.
  ToolResult<void> unregister(String toolId);

  /// Get a tool definition by [toolId].
  ///
  /// Returns [Result.success] with the [ToolDefinition],
  /// or [Result.failure] if the tool is not registered.
  ToolResult<ToolDefinition> getDefinition(String toolId);

  /// Get all registered tool definitions.
  List<ToolDefinition> getAll();

  /// Get all registered tools in a given [category].
  List<ToolDefinition> getByCategory(ToolCategory category);

  /// Discover tools matching a query string.
  ///
  /// Searches across [ToolDefinition.name], [description], and [tags].
  /// Returns tools sorted by relevance.
  ToolResult<List<ToolDefinition>> discover(String query);

  /// Check whether a tool is allowed by the allowlist.
  ///
  /// FAIL CLOSED: if the tool has no allowlist entry, returns false.
  /// If the tool has an entry with [isAllowed] == false, returns false.
  bool isAllowed(String toolId);

  /// Get all allowlist entries.
  List<ToolAllowlistEntry> allowlistEntries();

  /// Add or update an allowlist entry.
  ///
  /// Returns [Result.success] with the updated [ToolAllowlistEntry],
  /// or [Result.failure] if the operation fails.
  ToolResult<ToolAllowlistEntry> setAllowlistEntry(
    ToolAllowlistEntry entry,
  );

  /// Remove a tool from the allowlist.
  ///
  /// FAIL CLOSED: removing an entry means the tool will be denied
  /// (since absence = denied).
  ToolResult<void> removeAllowlistEntry(String toolId);

  /// Get the current full registry state snapshot.
  ToolState currentState();

  /// Whether the registry is in offline mode.
  bool get isOffline;

  /// Refresh the registry (re-scan available tools, sync allowlist).
  ToolResult<void> refresh();
}
