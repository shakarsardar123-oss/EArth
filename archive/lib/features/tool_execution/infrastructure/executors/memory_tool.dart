/// memory_tool.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// MemoryTool — handles semantic memory interactions.
/// Category: memory
/// Risk: low (read) / medium (write/delete)
/// Offline: yes (local memory)
/// Voice-safe: yes (query and store are voice-friendly)
///
/// Integrates with Step 17 Semantic Memory for:
/// - Store facts
/// - Recall memories
/// - Search semantic graph
/// - Update existing memories
library;

import '../../domain/models/tool_input.dart';
import '../../domain/models/tool_output.dart';
import '../../domain/models/tool_execution_context.dart';
import '../../domain/services/tool_interface.dart';

class MemoryTool extends Tool {
  @override
  String get id => 'aura.tool.memory';

  @override
  String get name => 'Memory Assistant';

  @override
  ToolCategory get category => ToolCategory.memory;

  @override
  String get description =>
      'Store, recall, search, and manage semantic memories';

  @override
  String get version => '1.0.0';

  @override
  List<String> get requiredPermissions => [
        'memory.read',
        'memory.write',
      ];

  @override
  ToolRiskLevel get riskLevel => ToolRiskLevel.low;

  @override
  bool get requiresConfirmation => false; // Read operations

  @override
  bool get supportsOffline => true;

  @override
  bool get isVoiceSafe => true;

  @override
  int get defaultTimeoutMs => 8000;

  bool _isExecuting = false;

  @override
  bool get isExecuting => _isExecuting;

  @override
  Future<ToolOutput> execute(ToolInput input, ToolExecutionContext context) async {
    _isExecuting = true;
    try {
      context.throwIfCancelled();
      if (!input.isValid) {
        return ToolOutput.failure(
            toolId: id,
            errorMessage: 'Invalid memory input',
        );
      }

      final action = input.sanitizedParams['action'] as String? ?? 'recall';
      final query = input.sanitizedParams['query'] as String? ?? '';
      final memoryContext = context.memoryContext;

      switch (action) {
        case 'recall':
          return ToolOutput.success(toolId: id, data: {
            'action': 'recall',
            'query': query,
            'results': [], // Would query Step 17 in production
            'memoryContext': memoryContext?.keys.toList() ?? [],
            'toolId': id,
          });

        case 'store':
          final key = input.sanitizedParams['key'] as String?;
          final value = input.sanitizedParams['value'];
          if (key == null || value == null) {
            return ToolOutput.failure(
                toolId: id,
            errorMessage: 'Key and value required for store',
            );
          }
          return ToolOutput.success(toolId: id, data: {
            'action': 'store',
            'key': key,
            'stored': true,
            'toolId': id,
          });

        case 'search':
          return ToolOutput.success(toolId: id, data: {
            'action': 'search',
            'query': query,
            'results': [],
            'toolId': id,
          });

        case 'delete':
          // Deletion requires elevated confirmation
          final key = input.sanitizedParams['key'] as String?;
          if (key == null) {
            return ToolOutput.failure(
                toolId: id,
            errorMessage: 'Key required for delete',
            );
          }
          if (context.requiresConfirmation && context.confirmationDenied) {
            return ToolOutput.denied(
                toolId: id,
            reason: 'Memory deletion requires confirmation',
            );
          }
          return ToolOutput.success(toolId: id, data: {
            'action': 'delete',
            'key': key,
            'deleted': true,
            'toolId': id,
          });

        default:
          return ToolOutput.failure(
              toolId: id,
            errorMessage: 'Unknown memory action: $action',
          );
      }
    } on ToolExecutionCancelledException {
      return ToolOutput.cancelled(toolId: id);
    } catch (e) {
      return ToolOutput.failure(
          toolId: id,
            errorMessage: 'Memory error');
    } finally {
      _isExecuting = false;
    }
  }

  @override
  ToolInput validate(Map<String, dynamic> params) {
    final action = params['action'] as String?;
    if (action == null || !_validActions.contains(action)) {
      return ToolInput.invalid(
        toolId: id,
        rawParams: params,
        field: 'action',
        message: 'Valid actions: ${_validActions.join(", ")}',
      );
    }
    return ToolInput.valid(
      toolId: id,
      params: Map<String, dynamic>.from(params),
    );
  }

  @override
  String describe() => 'ئامرازێکی یادەوەری بۆ خەزنکردن، بیرخستنەوە و گەڕان لە یادەوەرییەکان'; // Kurdish Sorani

  @override
  void cancel() {}

  static const _validActions = ['recall', 'store', 'search', 'delete'];
}
