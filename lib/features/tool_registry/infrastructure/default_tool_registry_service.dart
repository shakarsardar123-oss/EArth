/// default_tool_registry_service.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Concrete implementation of [ToolRegistryService].
///
/// Uses in-memory maps for tool definitions and allowlist entries.
/// Supports offline mode with graceful degradation.
library;

import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/models.dart';
import 'package:aura_assistant/features/tool_registry/domain/services/services.dart';

/// Concrete implementation of [ToolRegistryService].
///
/// Manages tool definitions and allowlist entries in memory.
/// FAIL CLOSED: any unknown tool is treated as not registered
/// and not allowed.
class DefaultToolRegistryService implements ToolRegistryService {
  /// Registered tool definitions, keyed by toolId.
  final Map<String, ToolDefinition> _definitions = {};

  /// Allowlist entries, keyed by toolId.
  final Map<String, ToolAllowlistEntry> _allowlistEntries = {};

  /// Recent execution results (capped at [_maxRecentExecutions]).
  final List<ToolExecutionResult> _recentExecutions = [];

  /// Maximum number of recent executions to track.
  static const int _maxRecentExecutions = 100;

  /// Whether the service is in offline mode.
  bool _isOffline = false;

  /// Error message if the service is in an error state.
  String? _errorMessage;

  /// Last time the registry was refreshed.
  DateTime? _lastRefreshedAt;

  DefaultToolRegistryService();

  // ─── Registration ─────────────────────────────────────────────────

  @override
  ToolResult<ToolDefinition> register(ToolDefinition definition) {
    // Validate tool definition.
    if (definition.toolId.isEmpty) {
      return Result.failure(
        ToolFailure.registration(
          message: 'Cannot register tool with empty toolId',
        ),
      );
    }

    if (_definitions.containsKey(definition.toolId)) {
      // Update existing definition.
      _definitions[definition.toolId] = definition;
    } else {
      // Add new definition.
      _definitions[definition.toolId] = definition;
    }

    _lastRefreshedAt = DateTime.now();
    return Result.success(definition);
  }

  @override
  ToolResult<ToolDefinition> unregister(String toolId) {
    final removed = _definitions.remove(toolId);
    if (removed == null) {
      return Result.failure(
        ToolFailure.registration(
          message: 'Tool not found for unregistration: $toolId',
        ),
      );
    }

    // Also remove allowlist entry.
    _allowlistEntries.remove(toolId);

    _lastRefreshedAt = DateTime.now();
    return Result.success(removed);
  }

  // ─── Query ───────────────────────────────────────────────────────

  @override
  ToolResult<ToolDefinition> getDefinition(String toolId) {
    final def = _definitions[toolId];
    if (def == null) {
      // FAIL CLOSED: unknown tool = not found.
      return Result.failure(
        ToolFailure.discovery(
          message: 'Tool not found in registry: $toolId',
        ),
      );
    }
    return Result.success(def);
  }

  @override
  List<ToolDefinition> getAll() => List.unmodifiable(_definitions.values);

  @override
  List<ToolDefinition> getByCategory(ToolCategory category) {
    return _definitions.values
        .where((d) => d.effectiveCategory == category)
        .toList();
  }

  @override
  ToolResult<List<ToolDefinition>> discover(String query) {
    if (_isOffline) {
      // Offline mode: return cached tools only.
      // Discovery is limited but not blocked entirely.
      final results = _definitions.values.where((d) {
        final q = query.toLowerCase();
        return d.toolId.toLowerCase().contains(q) ||
            d.name.toLowerCase().contains(q) ||
            d.description.toLowerCase().contains(q) ||
            d.tags.any((t) => t.toLowerCase().contains(q)) ||
            d.category.name.toLowerCase().contains(q);
      }).toList();

      return Result.success(results);
    }

    final results = _definitions.values.where((d) {
      final q = query.toLowerCase();
      return d.toolId.toLowerCase().contains(q) ||
          d.name.toLowerCase().contains(q) ||
          d.description.toLowerCase().contains(q) ||
          d.tags.any((t) => t.toLowerCase().contains(q)) ||
          d.category.name.toLowerCase().contains(q);
    }).toList();

    return Result.success(results);
  }

  // ─── Allowlist ───────────────────────────────────────────────────

  @override
  bool isAllowed(String toolId) {
    final entry = _allowlistEntries[toolId];
    if (entry == null) {
      // FAIL CLOSED: no entry = not allowed.
      return false;
    }
    // FAIL CLOSED: explicitly not allowed = denied.
    if (!entry.isAllowed) {
      return false;
    }
    // Also check that the tool is actually registered and enabled.
    final def = _definitions[toolId];
    if (def == null) {
      // FAIL CLOSED: unregistered tool = not allowed.
      return false;
    }
    if (!def.isEnabled) {
      // FAIL CLOSED: disabled tool = not allowed.
      return false;
    }
    return true;
  }

  @override
  List<ToolAllowlistEntry> allowlistEntries() =>
      List.unmodifiable(_allowlistEntries.values);

  @override
  ToolResult<ToolAllowlistEntry> setAllowlistEntry(
    String toolId,
    bool isAllowed, {
    AllowlistSource addedBy = AllowlistSource.user,
    String reason = '',
  }) {
    // Validate that the tool exists.
    if (!_definitions.containsKey(toolId)) {
      // FAIL CLOSED: cannot allowlist an unregistered tool.
      return Result.failure(
        ToolFailure.allowlist(
          message: 'Cannot set allowlist for unregistered tool: $toolId',
        ),
      );
    }

    final entry = ToolAllowlistEntry(
      toolId: toolId,
      isAllowed: isAllowed,
      addedAt: DateTime.now(),
      addedBy: addedBy,
      reason: reason,
    );

    _allowlistEntries[toolId] = entry;
    return Result.success(entry);
  }

  @override
  ToolResult<ToolAllowlistEntry> removeAllowlistEntry(String toolId) {
    final removed = _allowlistEntries.remove(toolId);
    if (removed == null) {
      return Result.failure(
        ToolFailure.allowlist(
          message: 'Allowlist entry not found for tool: $toolId',
        ),
      );
    }
    return Result.success(removed);
  }

  // ─── State ───────────────────────────────────────────────────────

  @override
  ToolState get currentState {
    return ToolState(
      definitions: List.unmodifiable(_definitions.values),
      allowlistEntries: List.unmodifiable(_allowlistEntries.values),
      recentExecutions: List.unmodifiable(_recentExecutions),
      status: _effectiveStatus,
      errorMessage: _errorMessage,
      isOffline: _isOffline,
      lastRefreshedAt: _lastRefreshedAt,
      availableToolCount: _definitions.length,
    );
  }

  ToolRegistryStatus get _effectiveStatus {
    if (_errorMessage != null) return ToolRegistryStatus.error;
    if (_isOffline) return ToolRegistryStatus.offline;
    if (_definitions.isEmpty) return ToolRegistryStatus.initializing;
    return ToolRegistryStatus.ready;
  }

  @override
  bool get isOffline => _isOffline;

  @override
  Future<ToolResult<void>> refresh() async {
    try {
      _errorMessage = null;
      _lastRefreshedAt = DateTime.now();

      // In a real implementation, this would re-fetch definitions
      // from a remote source. For now, it just clears errors.
      return Result.success(null);
    } catch (e) {
      _errorMessage = e.toString();
      return Result.failure(
        ToolFailure.discovery(
          message: 'Refresh failed: $e',
        ),
      );
    }
  }

  // ─── Execution Tracking ─────────────────────────────────────────

  /// Record a tool execution result.
  ///
  /// This is called by the execution gate after a tool runs.
  void recordExecution(ToolExecutionResult result) {
    _recentExecutions.add(result);
    // Cap the list size.
    while (_recentExecutions.length > _maxRecentExecutions) {
      _recentExecutions.removeAt(0);
    }
  }

  // ─── Offline Control ────────────────────────────────────────────

  /// Set the offline mode.
  void setOffline(bool offline) {
    _isOffline = offline;
    if (offline) {
      _errorMessage = null; // Offline is not an error.
    }
  }

  /// Set an error message.
  void setError(String? message) {
    _errorMessage = message;
  }

  // ─── Bulk Registration ──────────────────────────────────────────

  /// Register multiple tool definitions at once.
  ///
  /// Returns the number of successfully registered tools.
  int registerAll(List<ToolDefinition> definitions) {
    var count = 0;
    for (final def in definitions) {
      final result = register(def);
      if (result.isSuccess) count++;
    }
    return count;
  }

  /// Set multiple allowlist entries at once.
  ///
  /// Returns the number of successfully set entries.
  int setAllowlistEntries(
    List<MapEntry<String, bool>> entries, {
    AllowlistSource addedBy = AllowlistSource.user,
    String reason = '',
  }) {
    var count = 0;
    for (final entry in entries) {
      final result = setAllowlistEntry(
        entry.key,
        entry.value,
        addedBy: addedBy,
        reason: reason,
      );
      if (result.isSuccess) count++;
    }
    return count;
  }

  /// Clear all definitions and allowlist entries.
  ///
  /// Useful for testing or full reset.
  void clear() {
    _definitions.clear();
    _allowlistEntries.clear();
    _recentExecutions.clear();
    _errorMessage = null;
    _lastRefreshedAt = null;
  }
}
