/// step20_gate_adapter.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Adapter that bridges API mismatches between Step 20's abstract
/// ToolExecutionGate interface and the concrete DefaultToolExecutionGate.
///
/// Key mismatches bridged:
/// 1. Abstract execute({toolId, params}) vs concrete execute(toolId, {parameters, context})
/// 2. Abstract canExecute(toolId)→ToolResult<ToolDefinition> vs
///    concrete checkReadiness(toolId)→ToolExecutionReadiness
/// 3. Abstract checkPermissions() vs concrete _permissionAdapter.check(permId)
/// 4. Abstract ToolExecutor typedef Function(String,Map) vs
///    concrete executor(parameters, {memoryContext, toolContext})
/// 5. Abstract getExecutor() vs concrete direct executor field
///
/// FAIL CLOSED: any adapter failure defaults to denied/not-registered.
/// NEVER modifies Step 20 source — wraps from outside.
library;

import 'package:aura_assistant/features/tool_registry/domain/models/tool_definition.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/tool_execution_result.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/tool_failure.dart';
import 'package:aura_assistant/features/tool_registry/application/tool_execution_gate.dart';
import 'package:aura_assistant/features/tool_registry/infrastructure/default_tool_execution_gate.dart';

/// Adapter bridging Step 20's DefaultToolExecutionGate to Step 22's needs.
///
/// Wraps the concrete gate implementation and normalizes its API
/// to match what the ToolExecutionEngine expects.
///
/// All methods are FAIL CLOSED — any error or unknown state
/// results in a safe denial.
class Step20GateAdapter {
  /// Reference to Step 20's concrete gate.
  /// In production, this is obtained from Step 20's Riverpod providers.
  final DefaultToolExecutionGate? _concreteGate;

  /// Fallback registry of tool IDs known to Step 22.
  final Set<String> _knownTools;

  /// Permission check results cache (toolId → hasPermissions).
  final Map<String, bool> _permissionCache = {};

  Step20GateAdapter({
    DefaultToolExecutionGate? concreteGate,
    Set<String>? knownTools,
  })  : _concreteGate = concreteGate,
        _knownTools = knownTools ?? {};

  // ─── Gate bridging methods ──────────────────────────────────────────

  /// Bridge: isToolRegistered
  /// Maps to DefaultToolExecutionGate.isToolRegistered(toolId) if available,
  /// otherwise checks our fallback set.
  bool isToolRegistered(String toolId) {
    try {
      if (_concreteGate != null) {
        // Step 20 concrete gate has isToolRegistered()
        return _concreteGate!.isToolAllowed(toolId) &&
            _concreteGate!.isToolRegistered(toolId);
      }
      return _knownTools.contains(toolId);
    } catch (e) {
      // FAIL CLOSED: if check fails, assume not registered
      return false;
    }
  }

  /// Bridge: checkReadiness
  /// Maps to DefaultToolExecutionGate.checkReadiness(toolId).
  /// Returns true if tool is ready, false otherwise.
  bool checkReadiness(String toolId) {
    try {
      if (_concreteGate != null) {
        final readiness = _concreteGate!.checkReadiness(toolId);
        // ToolExecutionReadiness has .ready and .notReady(reason)
        // We check if it's the ready variant
        return readiness.toString().contains('ready') &&
            !readiness.toString().contains('notReady');
      }
      // If no concrete gate, assume ready if registered
      return isToolRegistered(toolId);
    } catch (e) {
      // FAIL CLOSED
      return false;
    }
  }

  /// Bridge: checkPermissions
  /// Maps to DefaultToolExecutionGate's _permissionAdapter.check(permId).
  bool checkPermissions(String toolId) {
    try {
      // Check cache first
      if (_permissionCache.containsKey(toolId)) {
        return _permissionCache[toolId]!;
      }

      if (_concreteGate != null) {
        // Step 20 concrete gate checks permissions internally
        // via _permissionAdapter.check(permId) during execution.
        // We bridge by calling isToolAllowed which does permission check.
        final allowed = _concreteGate!.isToolAllowed(toolId);
        _permissionCache[toolId] = allowed;
        return allowed;
      }

      // FAIL CLOSED: if no gate, assume no permissions
      return false;
    } catch (e) {
      _permissionCache[toolId] = false;
      return false;
    }
  }

  /// Bridge: requiresConfirmation
  /// Checks if a tool requires user confirmation before execution.
  bool requiresConfirmation(String toolId) {
    try {
      if (_concreteGate != null) {
        // Get the tool definition to check confirmation requirements
        final definition = _getDefinition(toolId);
        if (definition != null) {
          // Check the definition's requiresConfirmation flag
          return definition.requiresConfirmation;
        }
      }
      // Default: require confirmation for unknown tools (FAIL CLOSED)
      return true;
    } catch (e) {
      return true; // FAIL CLOSED
    }
  }

  /// Bridge: getToolDefinition
  /// Maps to DefaultToolExecutionGate.getDefinition(toolId).
  ToolDefinition? _getDefinition(String toolId) {
    try {
      if (_concreteGate != null) {
        return _concreteGate!.getDefinition(toolId);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Bridge: execute (signature normalization)
  /// Adapts Step 22's {toolId, params} call pattern to Step 20's
  /// (toolId, {parameters, context}) pattern.
  ///
  /// Step 20 abstract: execute({required toolId, required Map params})
  /// Step 20 concrete: execute(toolId, {Map? parameters, String? context})
  Future<ToolExecutionResult> executeBridged(
    String toolId,
    Map<String, dynamic> params, {
    String? memoryContext,
    String? toolContext,
  }) async {
    try {
      if (_concreteGate != null) {
        // Call the concrete gate with the right signature
        return await _concreteGate!.execute(
          toolId,
          parameters: params,
          context: toolContext,
        );
      }
      // No gate available — FAIL CLOSED
      return ToolExecutionResult(
        toolId: toolId,
        success: false,
        errorMessage: 'No execution gate available',
        executionDuration: Duration.zero,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return ToolExecutionResult(
        toolId: toolId,
        success: false,
        errorMessage: 'Gate execution error: $e',
        executionDuration: Duration.zero,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Bridge: ToolExecutor signature adaptation.
  ///
  /// Step 20 abstract defines ToolExecutor as
  ///   Future<ToolExecutionResult> Function(String, Map)
  ///
  /// But DefaultToolExecutionGate calls executor as
  ///   executor(parameters, {memoryContext, toolContext})
  ///
  /// This adapter wraps a Step 20 executor to match the abstract signature.
  static Future<ToolExecutionResult> Function(String, Map<String, dynamic>)
      wrapExecutor(
    Future<ToolExecutionResult> Function(
      Map<String, dynamic>, {
      String? memoryContext,
      String? toolContext,
    }) concreteExecutor, {
    String? memoryContext,
    String? toolContext,
  }) {
    return (String toolId, Map<String, dynamic> params) async {
      try {
        return await concreteExecutor(
          params,
          memoryContext: memoryContext,
          toolContext: toolContext,
        );
      } catch (e) {
        return ToolExecutionResult(
          toolId: toolId,
          success: false,
          errorMessage: 'Executor bridge error: $e',
          executionDuration: Duration.zero,
          timestamp: DateTime.now(),
        );
      }
    };
  }

  /// Register a tool ID in the fallback set.
  void registerKnownTool(String toolId) => _knownTools.add(toolId);

  /// Clear permission cache.
  void clearPermissionCache() => _permissionCache.clear();
}
