/// tool_executor_registry.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Registry mapping toolId → Tool instance.
/// Supports registration, unregistration, lookup, and category queries.
///
/// This is the central registry that the ToolExecutionEngine uses
/// to find and instantiate concrete tool implementations.
///
/// FAIL CLOSED: unknown tool → null (caller must deny execution).
library;

import '../../domain/services/tool_interface.dart';

/// Registry of tool executor instances.
///
/// Maps toolId → Tool instance, providing:
/// - Registration and unregistration
/// - Lookup by ID, category, risk level
/// - Batch operations
/// - Thread-safe iteration (snapshot for concurrent access)
class ToolExecutorRegistry {
  /// Map of toolId → Tool instance.
  final Map<String, Tool> _tools = {};

  /// Optional parent registry for hierarchical lookup.
  final ToolExecutorRegistry? _parent;

  ToolExecutorRegistry({ToolExecutorRegistry? parent}) : _parent = parent;

  // ─── Registration ──────────────────────────────────────────────────

  /// Register a tool instance.
  ///
  /// Returns true if registration succeeded.
  /// Returns false if a tool with the same ID already exists
  /// (prevents accidental overwrites).
  bool register(Tool tool) {
    if (_tools.containsKey(tool.id)) {
      return false; // Prevent overwrite
    }
    _tools[tool.id] = tool;
    return true;
  }

  /// Register a tool, overwriting any existing tool with the same ID.
  void forceRegister(Tool tool) {
    _tools[tool.id] = tool;
  }

  /// Unregister a tool by ID.
  ///
  /// Returns the removed tool, or null if not found.
  Tool? unregister(String toolId) => _tools.remove(toolId);

  /// Register multiple tools at once.
  void registerAll(List<Tool> tools) {
    for (final tool in tools) {
      forceRegister(tool);
    }
  }

  /// Clear all registered tools.
  void clear() => _tools.clear();

  // ─── Lookup ────────────────────────────────────────────────────────

  /// Get a tool by ID.
  ///
  /// Searches local registry first, then parent.
  /// Returns null if not found (FAIL CLOSED — caller must deny).
  Tool? get(String toolId) {
    final local = _tools[toolId];
    if (local != null) return local;
    return _parent?.get(toolId);
  }

  /// Check if a tool is registered.
  bool isRegistered(String toolId) =>
      _tools.containsKey(toolId) || (_parent?.isRegistered(toolId) ?? false);

  /// Get all registered tool IDs.
  List<String> get allIds =>
      {..._tools.keys, ...?_parent?.allIds}.toList();

  /// Get all registered tools.
  List<Tool> get allTools =>
      {..._tools.values, ...?(_parent?.allTools ?? <Tool>[])}.toList();

  /// Number of tools in this registry (local only, not parent).
  int get count => _tools.length;

  // ─── Category queries ──────────────────────────────────────────────

  /// Get tools by category.
  List<Tool> byCategory(ToolCategory category) =>
      allTools.where((t) => t.category == category).toList();

  /// Get tools by risk level.
  List<Tool> byRiskLevel(ToolRiskLevel riskLevel) =>
      allTools.where((t) => t.riskLevel == riskLevel).toList();

  /// Get tools that support offline execution.
  List<Tool> get offlineTools =>
      allTools.where((t) => t.supportsOffline).toList();

  /// Get tools that are voice-safe.
  List<Tool> get voiceSafeTools =>
      allTools.where((t) => t.isVoiceSafe).toList();

  /// Get tools that require confirmation.
  List<Tool> get confirmationRequiredTools =>
      allTools.where((t) => t.requiresConfirmation).toList();

  /// Get all unique categories present in the registry.
  List<ToolCategory> get categories {
    final cats = <ToolCategory>{};
    for (final tool in allTools) {
      cats.add(tool.category);
    }
    return cats.toList();
  }

  // ─── Snapshot ──────────────────────────────────────────────────────

  /// Create a snapshot (copy) of current tool registrations.
  /// Useful for concurrent iteration without mutation concerns.
  Map<String, Tool> snapshot() => Map.unmodifiable(_tools);

  // ─── Validation ────────────────────────────────────────────────────

  /// Validate that all registered tools have valid metadata.
  ///
  /// Returns a list of validation issues (empty if all valid).
  List<RegistryValidationIssue> validate() {
    final issues = <RegistryValidationIssue> [];

    for (final tool in _tools.values) {
      if (tool.id.isEmpty) {
        issues.add(RegistryValidationIssue(
          toolId: tool.id,
          field: 'id',
          message: 'Tool ID cannot be empty',
          severity: ValidationSeverity.critical,
        ));
      }

      if (tool.name.isEmpty) {
        issues.add(RegistryValidationIssue(
          toolId: tool.id,
          field: 'name',
          message: 'Tool name cannot be empty',
          severity: ValidationSeverity.critical,
        ));
      }

      if (tool.requiredPermissions.isEmpty &&
          tool.riskLevel != ToolRiskLevel.low) {
        issues.add(RegistryValidationIssue(
          toolId: tool.id,
          field: 'requiredPermissions',
          message:
              'Non-low-risk tool has no required permissions',
          severity: ValidationSeverity.warning,
        ));
      }

      if (tool.defaultTimeoutMs <= 0) {
        issues.add(RegistryValidationIssue(
          toolId: tool.id,
          field: 'defaultTimeoutMs',
          message: 'Timeout must be positive',
          severity: ValidationSeverity.warning,
        ));
      }
    }

    return issues;
  }
}

/// Validation issue for registry tools.
class RegistryValidationIssue {
  final String toolId;
  final String field;
  final String message;
  final ValidationSeverity severity;

  const RegistryValidationIssue({
    required this.toolId,
    required this.field,
    required this.message,
    this.severity = ValidationSeverity.warning,
  });
}

/// Severity of a validation issue.
enum ValidationSeverity {
  info,
  warning,
  critical,
  ;
}
