/// tool_state.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Reactive state model for the tool registry feature.
/// @immutable + copyWith with clear* bool flags (SecurityConfig pattern).
///
/// Consumed by [ToolRegistryStateNotifier] and exposed via Riverpod.
library;

import 'package:flutter/foundation.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/tool_definition.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/tool_allowlist_entry.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/tool_execution_result.dart';

/// Overall status of the tool registry.
enum ToolRegistryStatus {
  /// Registry is initializing (loading definitions).
  initializing,

  /// Registry is ready — tools can be discovered and (if allowed) executed.
  ready,

  /// Registry encountered an error during initialization.
  error,

  /// Registry is in offline mode — only offline-capable tools are available.
  offline,

  /// Status could not be determined. FAIL CLOSED → treat as offline.
  unknown,
}

/// Reactive state for the tool registry feature.
///
/// Contains the full registry snapshot: all tool definitions, allowlist
/// entries, recent execution results, and the current registry status.
@immutable
class ToolState {
  /// All registered tool definitions, keyed by toolId.
  final Map<String, ToolDefinition> definitions;

  /// Allowlist entries, keyed by toolId.
  final Map<String, ToolAllowlistEntry> allowlistEntries;

  /// Recent execution results (capped to last N).
  final List<ToolExecutionResult> recentExecutions;

  /// Current status of the registry.
  final ToolRegistryStatus status;

  /// Error message if [status] == [ToolRegistryStatus.error].
  final String? errorMessage;

  /// Whether the device is currently offline.
  final bool isOffline;

  /// Last time the registry was fully refreshed (UTC ISO 8601).
  final String lastRefreshedAt;

  /// Number of tools currently available (enabled + allowed).
  final int availableToolCount;

  const ToolState({
    this.definitions = const {},
    this.allowlistEntries = const {},
    this.recentExecutions = const [],
    this.status = ToolRegistryStatus.initializing,
    this.errorMessage,
    this.isOffline = false,
    this.lastRefreshedAt = '',
    this.availableToolCount = 0,
  });

  /// Whether a specific tool is allowed (has an allowlist entry with isAllowed=true).
  /// FAIL CLOSED: no entry → denied.
  bool isToolAllowed(String toolId) {
    final entry = allowlistEntries[toolId];
    if (entry == null) return false; // FAIL CLOSED: absent = denied
    return entry.isAllowed;
  }

  /// Whether a specific tool is enabled (definition exists and isEnabled=true).
  /// FAIL CLOSED: no definition → not enabled.
  bool isToolEnabled(String toolId) {
    final def = definitions[toolId];
    if (def == null) return false; // FAIL CLOSED
    return def.isEnabled;
  }

  /// Whether a specific tool can be executed (enabled AND allowed).
  /// FAIL CLOSED: either missing → denied.
  bool canExecute(String toolId) => isToolEnabled(toolId) && isToolAllowed(toolId);

  /// Tools grouped by category.
  Map<ToolCategory, List<ToolDefinition>> get toolsByCategory {
    final map = <ToolCategory, List<ToolDefinition>>{};
    for (final def in definitions.values) {
      final cat = def.effectiveCategory;
      (map[cat] ??= <ToolDefinition>[]).add(def);
    }
    return map;
  }

  /// Tools that are allowed but currently disabled.
  List<ToolDefinition> get allowedButDisabled => definitions.values
      .where((d) => isToolAllowed(d.toolId) && !d.isEnabled)
      .toList();

  /// Tools that are enabled but not allowed (on allowlist).
  List<ToolDefinition> get enabledButNotAllowed => definitions.values
      .where((d) => d.isEnabled && !isToolAllowed(d.toolId))
      .toList();

  /// Effective status. FAIL CLOSED: [unknown] → [offline].
  ToolRegistryStatus get effectiveStatus =>
      status == ToolRegistryStatus.unknown
          ? ToolRegistryStatus.offline
          : status;

  /// copyWith with clear* bool flags for collection fields.
  ToolState copyWith({
    Map<String, ToolDefinition>? definitions,
    bool clearDefinitions = false,
    Map<String, ToolAllowlistEntry>? allowlistEntries,
    bool clearAllowlistEntries = false,
    List<ToolExecutionResult>? recentExecutions,
    bool clearRecentExecutions = false,
    ToolRegistryStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isOffline,
    String? lastRefreshedAt,
    int? availableToolCount,
  }) {
    return ToolState(
      definitions: clearDefinitions
          ? const {}
          : (definitions ?? this.definitions),
      allowlistEntries: clearAllowlistEntries
          ? const {}
          : (allowlistEntries ?? this.allowlistEntries),
      recentExecutions: clearRecentExecutions
          ? const []
          : (recentExecutions ?? this.recentExecutions),
      status: status ?? this.status,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      isOffline: isOffline ?? this.isOffline,
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
      availableToolCount: availableToolCount ?? this.availableToolCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolState &&
          runtimeType == other.runtimeType &&
          definitions.length == other.definitions.length &&
          allowlistEntries.length == other.allowlistEntries.length &&
          status == other.status &&
          isOffline == other.isOffline;

  @override
  int get hashCode => Object.hash(
        definitions.length,
        allowlistEntries.length,
        status,
        isOffline,
      );

  @override
  String toString() =>
      'ToolState(status: $status, tools: ${definitions.length}, '
      'allowed: ${allowlistEntries.values.where((e) => e.isAllowed).length}, '
      'offline: $isOffline)';
}
