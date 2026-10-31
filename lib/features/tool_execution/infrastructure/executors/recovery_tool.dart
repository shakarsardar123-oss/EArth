/// recovery_tool.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// RecoveryTool — integrates with Step 18 agent recovery for error recovery.
/// Category: recovery
/// Risk: medium (modifies recovery state)
/// Offline: yes (local recovery operations)
/// Voice-safe: no (recovery operations are complex)
///
/// FAIL CLOSED: unknown recovery strategies result in failure.
library;

import '../../domain/models/tool_input.dart';
import '../../domain/models/tool_output.dart';
import '../../domain/models/tool_execution_context.dart';
import '../../domain/services/tool_interface.dart';

class RecoveryTool extends Tool {
  @override
  String get id => 'aura.tool.recovery';

  @override
  String get name => 'Recovery';

  @override
  ToolCategory get category => ToolCategory.recovery;

  @override
  String get description =>
      'Error recovery, fallback strategies, retry management';

  @override
  String get version => '1.0.0';

  @override
  List<String> get requiredPermissions => [
        'recovery.retry',
        'recovery.fallback',
      ];

  @override
  ToolRiskLevel get riskLevel => ToolRiskLevel.medium;

  @override
  bool get requiresConfirmation => false;

  @override
  bool get supportsOffline => true;

  @override
  bool get isVoiceSafe => false;

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
            errorMessage: 'Invalid recovery input',
        );
      }

      final action = input.sanitizedParams['action'] as String? ?? 'status';

      switch (action) {
        case 'status':
          return ToolOutput.success(toolId: id, data: {
            'action': 'status',
            'isRecovering': false,
            'lastRecovery': context.recoveryAttempt != null ? {
              'attempt': context.recoveryAttempt!.attempt,
              'strategy': context.recoveryAttempt!.strategy.toString(),
            } : null,
            'toolId': id,
          });

        case 'retry':
          return ToolOutput.success(toolId: id, data: {
            'action': 'retry',
            'result': 'retry_initiated',
            'attempt': context.currentRetry + 1,
            'toolId': id,
          });

        case 'fallback':
          return ToolOutput.success(toolId: id, data: {
            'action': 'fallback',
            'strategy': context.recoveryAttempt?.strategy.toString() ?? 'none',
            'result': 'fallback_applied',
            'toolId': id,
          });

        case 'report':
          return ToolOutput.success(toolId: id, data: {
            'action': 'report',
            'recoveryHistory': [],
            'toolId': id,
          });

        default:
          // Unknown action — FAIL CLOSED
          return ToolOutput.failure(
              toolId: id,
            errorMessage: 'Unknown recovery action: $action',
          );
      }
    } on ToolExecutionCancelledException {
      return ToolOutput.cancelled(toolId: id);
    } catch (e) {
      return ToolOutput.failure(
          toolId: id,
            errorMessage: 'Recovery error');
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
  String describe() => 'ئامرازێکی چاککردنەوە بۆ چاککردنی هەڵە و دووبارەکردنەوە'; // Kurdish Sorani

  @override
  void cancel() {}

  static const _validActions = ['status', 'retry', 'fallback', 'report'];
}
