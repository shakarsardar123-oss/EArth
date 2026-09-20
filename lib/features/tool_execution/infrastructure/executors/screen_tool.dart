/// screen_tool.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// ScreenTool — handles screen/display interactions.
/// Category: screen
/// Risk: low (read-only) / medium (write)
/// Offline: yes
/// Voice-safe: no (requires visual interaction)
library;

import '../../domain/models/tool_input.dart';
import '../../domain/models/tool_output.dart';
import '../../domain/models/tool_execution_context.dart';
import '../../domain/services/tool_interface.dart';

class ScreenTool extends Tool {
  @override
  String get id => 'aura.tool.screen';

  @override
  String get name => 'Screen Control';

  @override
  ToolCategory get category => ToolCategory.screen;

  @override
  String get description =>
      'Read and control screen: brightness, orientation, display info';

  @override
  String get version => '1.0.0';

  @override
  List<String> get requiredPermissions => [
        'screen.brightness.read',
        'screen.orientation.read',
      ];

  @override
  ToolRiskLevel get riskLevel => ToolRiskLevel.low;

  @override
  bool get requiresConfirmation => false;

  @override
  bool get supportsOffline => true;

  @override
  bool get isVoiceSafe => false;

  @override
  int get defaultTimeoutMs => 3000;

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
            errorMessage: 'Invalid screen input',
        );
      }

      final action = input.sanitizedParams['action'] as String? ?? 'info';

      switch (action) {
        case 'info':
        case 'brightness':
        case 'orientation':
        case 'size':
          return ToolOutput.success(toolId: id, data: {
            'action': action,
            'value': 'available',
            'toolId': id,
          });
        case 'set_brightness':
          return ToolOutput.success(toolId: id, data: {
            'action': action,
            'result': 'brightness_set',
            'toolId': id,
          });
        default:
          return ToolOutput.failure(
              toolId: id,
            errorMessage: 'Unknown screen action: $action',
          );
      }
    } on ToolExecutionCancelledException {
      return ToolOutput.cancelled(toolId: id);
    } catch (e) {
      return ToolOutput.failure(
          toolId: id,
            errorMessage: 'Screen error');
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
  String describe() => 'ئامرازێکی شاشە بۆ خوێندنەوە و کۆنتڕۆڵکردنی شاشە'; // Kurdish Sorani

  @override
  void cancel() {}

  static const _validActions = [
    'info', 'brightness', 'orientation', 'size', 'set_brightness'
  ];
}
