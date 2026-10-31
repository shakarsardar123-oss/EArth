/// assistant_tool.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// AssistantTool — handles assistant-level interactions.
/// Category: assistant
/// Risk: low (query) / medium (actions affecting assistant state)
/// Offline: yes (local assistant state)
/// Voice-safe: yes (primary assistant interface)
library;

import '../../domain/models/tool_input.dart';
import '../../domain/models/tool_output.dart';
import '../../domain/models/tool_execution_context.dart';
import '../../domain/services/tool_interface.dart';

class AssistantTool extends Tool {
  @override
  String get id => 'aura.tool.assistant';

  @override
  String get name => 'Assistant Control';

  @override
  ToolCategory get category => ToolCategory.assistant;

  @override
  String get description =>
      'Manage assistant state, preferences, configuration, and status';

  @override
  String get version => '1.0.0';

  @override
  List<String> get requiredPermissions => [
        'assistant.status',
        'assistant.preferences',
      ];

  @override
  ToolRiskLevel get riskLevel => ToolRiskLevel.low;

  @override
  bool get requiresConfirmation => false;

  @override
  bool get supportsOffline => true;

  @override
  bool get isVoiceSafe => true;

  @override
  int get defaultTimeoutMs => 5000;

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
            errorMessage: 'Invalid assistant input',
        );
      }

      final action = input.sanitizedParams['action'] as String? ?? 'status';

      switch (action) {
        case 'status':
          return ToolOutput.success(toolId: id, data: {
            'action': 'status',
            'state': 'active',
            'version': version,
            'toolId': id,
          });
        case 'preferences':
          return ToolOutput.success(toolId: id, data: {
            'action': 'preferences',
            'locale': context.locale,
            'toolId': id,
          });
        case 'configure':
          return ToolOutput.success(toolId: id, data: {
            'action': 'configure',
            'result': 'configuration_updated',
            'toolId': id,
          });
        case 'reset':
          if (context.confirmationDenied) {
            return ToolOutput.denied(
                toolId: id,
            reason: 'Assistant reset requires confirmation',
            );
          }
          return ToolOutput.success(toolId: id, data: {
            'action': 'reset',
            'result': 'reset_complete',
            'toolId': id,
          });
        default:
          return ToolOutput.failure(
              toolId: id,
            errorMessage: 'Unknown assistant action: $action',
          );
      }
    } on ToolExecutionCancelledException {
      return ToolOutput.cancelled(toolId: id);
    } catch (e) {
      return ToolOutput.failure(
          toolId: id,
            errorMessage: 'Assistant error');
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
  String describe() => 'ئامرازێکی یاریدەدەر بۆ بەڕێوەبردنی دۆخ و ڕێکخستنەکانی یاریدەدەر'; // Kurdish Sorani

  @override
  void cancel() {}

  static const _validActions = ['status', 'preferences', 'configure', 'reset'];
}
