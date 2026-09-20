/// device_tool.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// DeviceTool — handles hardware device interactions.
/// Category: device
/// Risk: medium (hardware access)
/// Offline: yes
/// Voice-safe: partial (query only, not config changes)
///
/// Capabilities: battery status, connectivity, hardware info,
/// device settings (requires confirmation), device actions.
library;

import '../../domain/models/tool_input.dart';
import '../../domain/models/tool_output.dart';
import '../../domain/models/tool_execution_context.dart';
import '../../domain/services/tool_interface.dart';

/// Concrete tool for device hardware interactions.
class DeviceTool extends Tool {
  @override
  String get id => 'aura.tool.device';

  @override
  String get name => 'Device Control';

  @override
  ToolCategory get category => ToolCategory.device;

  @override
  String get description =>
      'Access and control device hardware: battery, connectivity, settings';

  @override
  String get version => '1.0.0';

  @override
  List<String> get requiredPermissions => [
        'device.battery.read',
        'device.connectivity.read',
        'device.hardware.read',
      ];

  @override
  ToolRiskLevel get riskLevel => ToolRiskLevel.medium;

  @override
  bool get requiresConfirmation => true; // Config changes need confirmation

  @override
  bool get supportsOffline => true;

  @override
  bool get isVoiceSafe => false; // Not all operations are voice-safe

  @override
  int get defaultTimeoutMs => 5000;

  bool _isExecuting = false;
  bool _cancelled = false;

  @override
  bool get isExecuting => _isExecuting;

  @override
  Future<ToolOutput> execute(ToolInput input, ToolExecutionContext context) async {
    _isExecuting = true;
    _cancelled = false;

    try {
      context.throwIfCancelled();

      if (!input.isValid) {
        return ToolOutput.failure(
            toolId: id,
            errorMessage: 'Invalid input: ${input.validationIssues.map((i) => i.message).join(", ")}',
        );
      }

      final action = input.sanitizedParams['action'] as String? ?? 'status';

      // Check confirmation for destructive actions
      if (_isDestructiveAction(action) && context.requiresConfirmation) {
        // In production, this would trigger UI confirmation
        // For structural purposes, we check context
        if (context.confirmationDenied) {
          return ToolOutput.denied(
              toolId: id,
            reason: 'Confirmation denied for action: $action',
          );
        }
      }

      context.throwIfCancelled();

      // Execute based on action
      switch (action) {
        case 'status':
        case 'battery':
        case 'connectivity':
        case 'hardware':
          return ToolOutput.success(toolId: id, data: {
            'action': action,
            'status': 'available',
            'toolId': id,
            'timestamp': DateTime.now().toIso8601String(),
          });

        case 'settings':
          if (context.requiresConfirmation && context.confirmationDenied) {
            return ToolOutput.denied(
                toolId: id,
            reason: 'Settings modification requires confirmation',
            );
          }
          return ToolOutput.success(toolId: id, data: {
            'action': action,
            'result': 'settings_read',
            'toolId': id,
          });

        default:
          return ToolOutput.failure(
              toolId: id,
            errorMessage: 'Unknown device action: $action',
          );
      }
    } on ToolExecutionCancelledException {
      return ToolOutput.cancelled(toolId: id);
    } catch (e) {
      return ToolOutput.failure(
          toolId: id,
            errorMessage: 'Device tool error: ${_sanitizeError(e)}',
      );
    } finally {
      _isExecuting = false;
    }
  }

  @override
  ToolInput validate(Map<String, dynamic> params) {
    final action = params['action'] as String?;
    if (action == null) {
      return ToolInput.invalid(
        toolId: id,
        rawParams: params,
        field: 'action',
        message: 'Action is required',
      );
    } else if (!_validActions.contains(action)) {
      return ToolInput.invalid(
        toolId: id,
        rawParams: params,
        field: 'action',
        message: 'Invalid action: $action. Valid: ${_validActions.join(", ")}',
      );
    }
    return ToolInput.valid(
      toolId: id,
      params: Map<String, dynamic>.from(params),
    );
  }

  @override
  String describe() =>
      'ئامرازێکی ئامێر بۆ دەستگەیشتن بە باتری، پەیوەندی و ڕێکخستنەکانی ئامێر'; // Kurdish Sorani

  @override
  void cancel() {
    _cancelled = true;
  }

  bool _isDestructiveAction(String action) =>
      const ['settings', 'reset', 'shutdown', 'restart'].contains(action);

  String _sanitizeError(Object error) {
    final msg = error.toString();
    if (msg.length > 200) return msg.substring(0, 200);
    return msg;
  }

  static const _validActions = [
    'status', 'battery', 'connectivity', 'hardware', 'settings'
  ];
}
