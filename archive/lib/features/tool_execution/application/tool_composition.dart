/// tool_composition.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Tool composition service — chains multiple tools together.
/// KEY FIXES:
///   - ToolOutput.cancelled uses 'message' param
///   - ToolOutput.empty has NO data param
///   - All ToolOutput factories require toolId
///   - registry.get() NOT getTool()
///   - FAIL CLOSED: any failure in chain stops execution
library;

import '../domain/models/tool_output.dart';
import '../domain/models/tool_execution_context.dart';
import '../infrastructure/executors/tool_executor_registry.dart';

class ToolCompositionService {
  final ToolExecutorRegistry registry;

  ToolCompositionService({required this.registry});

  /// Execute a chain of tools in sequence.
  /// FAIL CLOSED: if any tool fails, the entire chain is cancelled.
  Future<ToolOutput> executeChain(
    List<String> toolIds,
    Map<String, dynamic> initialParams,
    ToolExecutionContext context,
  ) async {
    Map<String, dynamic> currentParams = Map.from(initialParams);
    ToolOutput? lastOutput;

    for (final toolId in toolIds) {
      final tool = registry.get(toolId);
      if (tool == null) {
        // Unknown tool — FAIL CLOSED
        return ToolOutput.denied(
          toolId: toolId,
          reason: 'Tool "$toolId" not found in registry — chain denied',
        );
      }

      final validatedInput = tool.validate(currentParams);
      if (validatedInput.hasErrors) {
        return ToolOutput.failure(
          toolId: toolId,
          errorMessage: 'Input validation failed: ${validatedInput.errors}',
        );
      }

      context.throwIfCancelled();

      lastOutput = await tool.execute(validatedInput, context);

      if (lastOutput.isFailure || lastOutput.isDenied || lastOutput.isCancelled) {
        return lastOutput;
      }

      // Pass output data to next tool in chain
      currentParams = Map<String, dynamic>.from(lastOutput.data as Map);
    }

    return lastOutput ?? ToolOutput.empty(toolId: 'composition');
  }
}
