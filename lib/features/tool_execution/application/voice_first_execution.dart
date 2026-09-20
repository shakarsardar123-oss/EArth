/// voice_first_execution.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Voice-first execution service — prioritizes voice-safe tools.
/// KEY FIXES:
///   - registry.byCategory() NOT getByCategory()
///   - registry.get() NOT getTool()
///   - registry.allTools NOT getAllTools()
///   - riskLevel is String
///   - FAIL CLOSED: if no voice-safe tool found, deny
library;

import '../domain/models/tool_output.dart';
import '../domain/models/tool_execution_context.dart';
import '../domain/services/tool_interface.dart';
import '../infrastructure/executors/tool_executor_registry.dart';

class VoiceFirstExecutionService {
  final ToolExecutorRegistry registry;

  VoiceFirstExecutionService({required this.registry});

  /// Execute with voice-first preference — picks voice-safe tools first.
  Future<ToolOutput> executeVoiceFirst(
    String toolId,
    Map<String, dynamic> params,
    ToolExecutionContext context,
  ) async {
    final tool = registry.get(toolId);
    if (tool == null) {
      return ToolOutput.denied(
        toolId: toolId,
        reason: 'Tool "$toolId" not found — voice execution denied',
      );
    }

    // Check if tool is voice-safe
    if (!tool.isVoiceSafe) {
      // Try to find a voice-safe alternative in same category
      final alternatives = registry.byCategory(tool.category.name);
      final voiceSafeAlt = alternatives.where((t) => t.isVoiceSafe).toList();

      if (voiceSafeAlt.isNotEmpty) {
        final altTool = voiceSafeAlt.first;
        final validatedInput = altTool.validate(params);
        if (!validatedInput.hasErrors) {
          return altTool.execute(validatedInput, context);
        }
      }

      // No voice-safe alternative — FAIL CLOSED
      return ToolOutput.denied(
        toolId: toolId,
        reason: 'No voice-safe alternative available for "${tool.name}"',
      );
    }

    final validatedInput = tool.validate(params);
    if (validatedInput.hasErrors) {
      return ToolOutput.failure(
        toolId: toolId,
        errorMessage: 'Validation failed for voice-first execution',
      );
    }

    context.throwIfCancelled();
    return tool.execute(validatedInput, context);
  }

  /// List all voice-safe tools.
  List<Tool> voiceSafeTools() {
    return registry.allTools.where((t) => t.isVoiceSafe).toList();
  }
}
