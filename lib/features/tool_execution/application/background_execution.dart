/// background_execution.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Background execution service — runs tools in background.
/// KEY FIXES:
///   - registry.get() NOT getTool()
///   - ToolOutput factories require toolId
///   - CancellationToken.cancel() takes NO arguments
///   - FAIL CLOSED: background errors default to failClosed
library;

import '../domain/models/tool_output.dart';
import '../domain/models/tool_execution_context.dart';
import '../domain/models/exceptions.dart';
import '../infrastructure/executors/tool_executor_registry.dart';
import '../infrastructure/cancellation_token.dart';

class BackgroundExecutionService {
  final ToolExecutorRegistry registry;

  BackgroundExecutionService({required this.registry});

  /// Execute a tool in the background with a cancellation token.
  Future<ToolOutput> executeInBackground(
    String toolId,
    Map<String, dynamic> params,
    ToolExecutionContext context,
    CancellationToken cancellationToken,
  ) async {
    final tool = registry.get(toolId);
    if (tool == null) {
      return ToolOutput.denied(
        toolId: toolId,
        reason: 'Tool "$toolId" not found — background execution denied',
      );
    }

    final validatedInput = tool.validate(params);
    if (validatedInput.hasErrors) {
      return ToolOutput.failure(
        toolId: toolId,
        errorMessage: 'Validation failed for background execution',
      );
    }

    try {
      // Monitor cancellation token
      final executionFuture = tool.execute(validatedInput, context);

      final result = await Future.any([
        executionFuture,
        _waitForCancellation(cancellationToken).then((_) => null),
      ]);

      if (result == null) {
        cancellationToken.cancel(); // cancel() takes NO arguments
        return ToolOutput.cancelled(toolId: toolId, message: 'Background execution cancelled via token');
      }

      return result;
    } catch (e) {
      if (e is ToolExecutionCancelledException) {
        return ToolOutput.cancelled(toolId: toolId);
      }
      return ToolOutput.failClosed(toolId: toolId, reason: 'Background error: $e');
    }
  }

  Future<void> _waitForCancellation(CancellationToken token) async {
    while (!token.isCancelled) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}
