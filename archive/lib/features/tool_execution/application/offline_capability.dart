/// offline_capability.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Offline capability service — manages tools available without network.
/// KEY FIXES:
///   - registry.get() NOT getTool()
///   - registry.allTools NOT getAllTools()
///   - ToolOutput.failure uses 'errorMessage' NOT 'message'
///   - FAIL CLOSED: if tool doesn't support offline, deny
library;

import '../domain/models/tool_output.dart';
import '../domain/models/tool_execution_context.dart';
import '../domain/services/tool_interface.dart';
import '../infrastructure/executors/tool_executor_registry.dart';

class OfflineCapabilityService {
  final ToolExecutorRegistry registry;

  OfflineCapabilityService({required this.registry});

  /// Execute a tool in offline mode.
  /// FAIL CLOSED: if tool doesn't support offline, deny.
  Future<ToolOutput> executeOffline(
    String toolId,
    Map<String, dynamic> params,
    ToolExecutionContext context,
  ) async {
    final tool = registry.get(toolId);
    if (tool == null) {
      return ToolOutput.denied(
        toolId: toolId,
        reason: 'Tool "$toolId" not found — offline execution denied',
      );
    }

    if (!tool.supportsOffline) {
      // FAIL CLOSED: tool doesn't support offline
      return ToolOutput.denied(
        toolId: toolId,
        reason: 'Tool "${tool.name}" does not support offline execution',
      );
    }

    final validatedInput = tool.validate(params);
    if (validatedInput.hasErrors) {
      return ToolOutput.failure(
        toolId: toolId,
        errorMessage: 'Validation failed for offline execution',
      );
    }

    try {
      return tool.execute(validatedInput, context);
    } catch (e) {
      return ToolOutput.failClosed(
        toolId: toolId,
        reason: 'Offline execution error: $e',
      );
    }
  }

  /// List all tools that support offline execution.
  List<Tool> offlineCapableTools() {
    return registry.allTools.where((t) => t.supportsOffline).toList();
  }
}
