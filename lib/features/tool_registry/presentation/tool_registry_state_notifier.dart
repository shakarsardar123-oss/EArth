/// tool_registry_state_notifier.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// [StateNotifier] that manages [ToolState] for the tool registry feature.
///
/// Uses [StreamController.broadcast()] for event-driven updates.
/// Follows the established pattern from Steps 15-19.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/models.dart';
import 'package:aura_assistant/features/tool_registry/domain/services/services.dart';
import 'package:aura_assistant/features/tool_registry/application/application.dart';
import 'package:aura_assistant/features/tool_registry/infrastructure/infrastructure.dart';

/// StateNotifier for the Tool Registry feature.
///
/// Manages [ToolState] and exposes a broadcast stream for event-driven
/// updates. All mutations go through the registry service, and the
/// state is refreshed after each mutation.
class ToolRegistryStateNotifier extends StateNotifier<ToolState> {
  final ToolRegistryService _registryService;
  final ToolConfirmationService _confirmationService;
  final ToolExecutionGate _executionGate;
  final ToolDiscoveryApi _discoveryApi;

  /// Broadcast stream controller for real-time event emission.
  final StreamController<ToolState> _streamController =
      StreamController<ToolState>.broadcast();

  /// Subscription for external events (if any).
  StreamSubscription? _externalSubscription;

  ToolRegistryStateNotifier({
    required ToolRegistryService registryService,
    required ToolConfirmationService confirmationService,
    required ToolExecutionGate executionGate,
    required ToolDiscoveryApi discoveryApi,
  })  : _registryService = registryService,
        _confirmationService = confirmationService,
        _executionGate = executionGate,
        _discoveryApi = discoveryApi,
        super(registryService.currentState);

  /// Broadcast stream of state changes.
  Stream<ToolState> get stream => _streamController.stream;

  /// Whether the notifier has been disposed.
  bool _isDisposed = false;

  // ─── Tool Registration ───────────────────────────────────────

  /// Register a tool definition.
  ToolResult<ToolDefinition> registerTool(ToolDefinition definition) {
    final result = _registryService.register(definition);
    _emit();
    return result;
  }

  /// Unregister a tool definition.
  ToolResult<ToolDefinition> unregisterTool(String toolId) {
    final result = _registryService.unregister(toolId);
    _emit();
    return result;
  }

  /// Register multiple tools at once.
  int registerTools(List<ToolDefinition> definitions) {
    if (_registryService is DefaultToolRegistryService) {
      final count = (_registryService as DefaultToolRegistryService)
          .registerAll(definitions);
      _emit();
      return count;
    }
    var count = 0;
    for (final def in definitions) {
      final result = _registryService.register(def);
      if (result.isSuccess) count++;
    }
    _emit();
    return count;
  }

  // ─── Allowlist Management ──────────────────────────────────────

  /// Set allowlist entry for a tool.
  ToolResult<ToolAllowlistEntry> setAllowlist(
    String toolId,
    bool isAllowed, {
    AllowlistSource addedBy = AllowlistSource.user,
    String reason = '',
  }) {
    final result = _registryService.setAllowlistEntry(
      toolId,
      isAllowed,
      addedBy: addedBy,
      reason: reason,
    );
    _emit();
    return result;
  }

  /// Remove allowlist entry for a tool.
  ToolResult<ToolAllowlistEntry> removeAllowlist(String toolId) {
    final result = _registryService.removeAllowlistEntry(toolId);
    _emit();
    return result;
  }

  /// Batch-set allowlist entries.
  int setAllowlistEntries(
    List<MapEntry<String, bool>> entries, {
    AllowlistSource addedBy = AllowlistSource.user,
    String reason = '',
  }) {
    if (_registryService is DefaultToolRegistryService) {
      final count = (_registryService as DefaultToolRegistryService)
          .setAllowlistEntries(entries, addedBy: addedBy, reason: reason);
      _emit();
      return count;
    }
    var count = 0;
    for (final entry in entries) {
      final result = _registryService.setAllowlistEntry(
        entry.key,
        entry.value,
        addedBy: addedBy,
        reason: reason,
      );
      if (result.isSuccess) count++;
    }
    _emit();
    return count;
  }

  // ─── Tool Execution ───────────────────────────────────────────

  /// Execute a tool via the execution gate.
  Future<ToolResult<ToolExecutionResult>> executeTool(
    String toolId, {
    Map<String, dynamic>? parameters,
    String? context,
  }) async {
    final result = await _executionGate.execute(
      toolId,
      parameters: parameters,
      context: context,
    );
    _emit();
    return result;
  }

  /// Check if a tool is ready to execute.
  Future<ToolExecutionReadiness> checkReadiness(String toolId) async {
    return _executionGate.checkReadiness(toolId);
  }

  // ─── Discovery ────────────────────────────────────────────────

  /// Discover tools by query.
  DiscoveryResult discoverTools(String query) {
    return _discoveryApi.discover(query);
  }

  /// Discover tools by category.
  DiscoveryResult discoverByCategory(ToolCategory category) {
    return _discoveryApi.discoverByCategory(category);
  }

  /// Discover tools by risk level.
  DiscoveryResult discoverByRiskLevel(ToolRiskLevel riskLevel) {
    return _discoveryApi.discoverByRiskLevel(riskLevel);
  }

  /// Get info about a specific tool.
  DiscoveredTool? getToolInfo(String toolId) {
    return _discoveryApi.getToolInfo(toolId);
  }

  /// Get available categories.
  List<ToolCategory> availableCategories() {
    return _discoveryApi.availableCategories();
  }

  // ─── Query ────────────────────────────────────────────────────

  /// Check if a tool is allowed.
  bool isToolAllowed(String toolId) => _registryService.isAllowed(toolId);

  /// Check if a tool is registered.
  bool isToolRegistered(String toolId) =>
      _registryService.getDefinition(toolId).isSuccess;

  /// Get all registered tools.
  List<ToolDefinition> get allTools => _registryService.getAll();

  /// Get tools by category.
  List<ToolDefinition> toolsByCategory(ToolCategory category) =>
      _registryService.getByCategory(category);

  // ─── Offline ─────────────────────────────────────────────────

  /// Set offline mode.
  void setOffline(bool offline) {
    if (_registryService is DefaultToolRegistryService) {
      (_registryService as DefaultToolRegistryService).setOffline(offline);
      _emit();
    }
  }

  /// Refresh the registry.
  Future<ToolResult<void>> refresh() async {
    final result = await _registryService.refresh();
    _emit();
    return result;
  }

  // ─── State Emission ──────────────────────────────────────────

  /// Emit the current state to the broadcast stream.
  void _emit() {
    if (_isDisposed) return;
    final newState = _registryService.currentState;
    state = newState;
    _streamController.add(newState);
  }

  // ─── Lifecycle ───────────────────────────────────────────────

  @override
  void dispose() {
    _isDisposed = true;
    _externalSubscription?.cancel();
    _streamController.close();
    super.dispose();
  }
}
