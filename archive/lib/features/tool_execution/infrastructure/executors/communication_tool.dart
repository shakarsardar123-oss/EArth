/// communication_tool.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// CommunicationTool — handles messaging/calling/sharing.
/// Category: communication
/// Risk: high (sending messages, making calls — user-facing actions)
/// Offline: no (requires network)
/// Voice-safe: yes (natural voice interaction for calls/messages)
library;

import '../../domain/models/tool_input.dart';
import '../../domain/models/tool_output.dart';
import '../../domain/models/tool_execution_context.dart';
import '../../domain/services/tool_interface.dart';

class CommunicationTool extends Tool {
  @override
  String get id => 'aura.tool.communication';

  @override
  String get name => 'Communication';

  @override
  ToolCategory get category => ToolCategory.communication;

  @override
  String get description =>
      'Send messages, make calls, share content with contacts';

  @override
  String get version => '1.0.0';

  @override
  List<String> get requiredPermissions => [
        'communication.sms',
        'communication.call',
        'communication.contacts',
      ];

  @override
  ToolRiskLevel get riskLevel => ToolRiskLevel.high;

  @override
  bool get requiresConfirmation => true; // ALL communication actions need confirmation

  @override
  bool get supportsOffline => false; // Network required

  @override
  bool get isVoiceSafe => true; // Voice-first communication

  @override
  int get defaultTimeoutMs => 15000;

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
            errorMessage: 'Invalid communication input',
        );
      }

      // ALL communication actions require confirmation
      if (context.confirmationDenied) {
        return ToolOutput.denied(
            toolId: id,
            reason: 'Communication action requires user confirmation',
        );
      }

      final action = input.sanitizedParams['action'] as String? ?? 'status';

      switch (action) {
        case 'send_message':
          final recipient = input.sanitizedParams['recipient'] as String?;
          final message = input.sanitizedParams['message'] as String?;
          if (recipient == null || message == null) {
            return ToolOutput.failure(
                toolId: id,
            errorMessage: 'Recipient and message required',
            );
          }
          return ToolOutput.success(toolId: id, data: {
            'action': 'send_message',
            'recipient': recipient,
            'status': 'sent',
            'toolId': id,
          });

        case 'call':
          final recipient = input.sanitizedParams['recipient'] as String?;
          if (recipient == null) {
            return ToolOutput.failure(
                toolId: id,
            errorMessage: 'Recipient required for call',
            );
          }
          return ToolOutput.success(toolId: id, data: {
            'action': 'call',
            'recipient': recipient,
            'status': 'calling',
            'toolId': id,
          });

        case 'share':
          return ToolOutput.success(toolId: id, data: {
            'action': 'share',
            'status': 'shared',
            'toolId': id,
          });

        case 'contacts':
          return ToolOutput.success(toolId: id, data: {
            'action': 'contacts',
            'list': [],
            'toolId': id,
          });

        default:
          return ToolOutput.failure(
              toolId: id,
            errorMessage: 'Unknown communication action: $action',
          );
      }
    } on ToolExecutionCancelledException {
      return ToolOutput.cancelled(toolId: id);
    } catch (e) {
      return ToolOutput.failure(
          toolId: id,
            errorMessage: 'Communication error');
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
  String describe() => 'ئامرازێکی پەیوەندی بۆ ناردنی پەیام، پەیوەندی تەلەفۆنی و هاوبەشکردن'; // Kurdish Sorani

  @override
  void cancel() {}

  static const _validActions = [
    'send_message', 'call', 'share', 'contacts'
  ];
}
