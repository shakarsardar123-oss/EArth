/// screen_target_tool.dart
/// AURA — Screen Understanding / Target Action bridge.
///
/// Connects the existing ScreenTargetOrchestrator to the Tool Execution
/// system without replacing the existing screen-understanding pipeline.
///
/// FAIL-CLOSED: unverified or unknown targets are never acted upon.
library;


import '../../../screen_target/application/screen_target_orchestrator.dart';
import '../../../screen_target/domain/models/correction_action.dart';
import '../../../screen_target/domain/models/screen_target.dart';
import '../../domain/models/tool_input.dart';
import '../../domain/models/tool_output.dart';
import '../../domain/models/tool_execution_context.dart';
import '../../domain/services/tool_interface.dart';

class ScreenTargetTool extends Tool {
  ScreenTargetTool({
    required ScreenTargetOrchestrator orchestrator,
  }) : _orchestrator = orchestrator;

  final ScreenTargetOrchestrator _orchestrator;

  bool _isExecuting = false;

  static const String _toolId = 'aura.tool.screen_target';

  static const Set<String> _validActions = {
    'scan',
    'find',
    'tap',
    'long_press',
    'swipe',
    'type_text',
    'scroll',
  };

  @override
  String get id => _toolId;

  @override
  String get name => 'Screen Understanding';

  @override
  ToolCategory get category => ToolCategory.screen;

  @override
  String get description =>
      'Understand the current screen, find visible targets, and perform '
      'verified screen actions.';

  @override
  String get version => '1.0.0';

  @override
  List<String> get requiredPermissions => const [
        'screen.capture',
        'screen.understanding',
        'screen.action',
      ];

  @override
  String get riskLevel => 'high';

  @override
  bool get requiresConfirmation => true;

  @override
  bool get supportsOffline => false;

  @override
  bool get isVoiceSafe => true;

  @override
  int get defaultTimeoutMs => 10000;

  @override
  bool get isExecuting => _isExecuting;

  @override
  Future<ToolOutput> execute(
    ToolInput input,
    ToolExecutionContext context,
  ) async {
    _isExecuting = true;

    try {
      context.throwIfCancelled();

      if (!input.isValid) {
        return ToolOutput.failure(
          toolId: id,
          errorMessage: 'Invalid screen-target input',
          errorCode: 'invalid_input',
          toolCategory: category.name,
        );
      }

      final params = input.sanitizedParams;
      final action = params['action'] as String?;

      if (action == null || !_validActions.contains(action)) {
        return ToolOutput.failClosed(
          toolId: id,
          reason: 'Unknown or unsupported screen-target action',
          toolCategory: category.name,
        );
      }

      final screenId = params['screenId'] as String?;
      if (screenId == null || screenId.trim().isEmpty) {
        return ToolOutput.failure(
          toolId: id,
          errorMessage: 'screenId is required',
          errorCode: 'missing_screen_id',
          toolCategory: category.name,
        );
      }

      context.throwIfCancelled();

      switch (action) {
        case 'scan':
          return _scan(
            screenId: screenId.trim(),
            verifyTargets: params['verifyTargets'] as bool? ?? true,
          );

        case 'find':
          final label = params['label'] as String?;
          if (label == null || label.trim().isEmpty) {
            return ToolOutput.failure(
              toolId: id,
              errorMessage: 'label is required',
              errorCode: 'missing_label',
              toolCategory: category.name,
            );
          }

          return _find(
            screenId: screenId.trim(),
            label: label.trim(),
          );

        case 'tap':
        case 'long_press':
        case 'swipe':
        case 'type_text':
        case 'scroll':
          return _performAction(
            action: action,
            screenId: screenId.trim(),
            label: params['label'] as String?,
            textInput: params['textInput'] as String?,
            swipeDirection: params['swipeDirection'] as String?,
          );
      }

      return ToolOutput.failClosed(
        toolId: id,
        reason: 'Unhandled screen-target action',
        toolCategory: category.name,
      );
    } on ToolExecutionCancelledException {
      return ToolOutput.cancelled(
        toolId: id,
        toolCategory: category.name,
      );
    } catch (_) {
      return ToolOutput.failClosed(
        toolId: id,
        reason: 'Screen-target execution failed',
        toolCategory: category.name,
      );
    } finally {
      _isExecuting = false;
    }
  }

  Future<ToolOutput> _scan({
    required String screenId,
    required bool verifyTargets,
  }) async {
    final verdict = await _orchestrator.scanScreen(
      screenId: screenId,
      verifyTargets: verifyTargets,
    );

    if (!verdict.isAllowed) {
      return ToolOutput.denied(
        toolId: id,
        reason: 'Screen scan denied: ${verdict.name}',
        errorCode: verdict.name,
        toolCategory: category.name,
      );
    }

    final result = await _orchestrator.getLatestResult(screenId);

    return ToolOutput.success(
      toolId: id,
      toolCategory: category.name,
      data: {
        'action': 'scan',
        'screenId': result.screenId,
        'resultId': result.resultId,
        'status': result.status.name,
        'locale': result.locale,
        'scanDurationMs': result.scanDurationMs,
        'verifiedCount': result.verifiedCount,
        'actionableCount': result.actionableCount,
        'targets': result.targets.map(_targetToMap).toList(),
      },
    );
  }

  Future<ToolOutput> _find({
    required String screenId,
    required String label,
  }) async {
    final target = await _orchestrator.findByLabel(
      screenId: screenId,
      label: label,
    );

    if (!target.verified || !target.isActionable) {
      return ToolOutput.denied(
        toolId: id,
        reason: 'Target was not verified or actionable',
        errorCode: 'target_not_verified',
        toolCategory: category.name,
      );
    }

    return ToolOutput.success(
      toolId: id,
      toolCategory: category.name,
      data: {
        'action': 'find',
        'screenId': screenId,
        'target': _targetToMap(target),
      },
    );
  }

  Future<ToolOutput> _performAction({
    required String action,
    required String screenId,
    String? label,
    String? textInput,
    String? swipeDirection,
  }) async {
    if (label == null || label.trim().isEmpty) {
      return ToolOutput.failure(
        toolId: id,
        errorMessage: 'label is required for screen actions',
        errorCode: 'missing_label',
        toolCategory: category.name,
      );
    }

    final target = await _orchestrator.findByLabel(
      screenId: screenId,
      label: label.trim(),
    );

    if (!target.verified || !target.isActionable) {
      return ToolOutput.denied(
        toolId: id,
        reason: 'Target was not verified or actionable',
        errorCode: 'target_not_verified',
        toolCategory: category.name,
      );
    }

    final actionType = _actionTypeFromName(action);
    if (actionType == null) {
      return ToolOutput.failClosed(
        toolId: id,
        reason: 'Unsupported correction action',
        toolCategory: category.name,
      );
    }

    final verdict = await _orchestrator.planAction(
      target: target,
      actionType: actionType,
      textInput: textInput,
      swipeDirection: swipeDirection,
    );

    if (!verdict.isAllowed) {
      return ToolOutput.denied(
        toolId: id,
        reason: 'Action planning denied: ${verdict.name}',
        errorCode: verdict.name,
        toolCategory: category.name,
      );
    }

    final plannedAction = CorrectionAction(
      actionId: 'aura-${DateTime.now().microsecondsSinceEpoch}',
      target: target,
      actionType: actionType,
      textInput: textInput ?? '',
      swipeDirection: swipeDirection ?? '',
      targetVerified: target.verified,
      result: CorrectionResult.unknown,
      executedAt: DateTime.now(),
      locale: target.locale,
    );

    final result = await _orchestrator.executeAction(plannedAction);

    if (!result.result.isSuccess) {
      return ToolOutput.denied(
        toolId: id,
        reason: 'Screen action failed: ${result.result.name}',
        errorCode: result.result.name,
        toolCategory: category.name,
      );
    }

    return ToolOutput.success(
      toolId: id,
      toolCategory: category.name,
      data: {
        'action': action,
        'screenId': screenId,
        'target': _targetToMap(result.target),
        'result': result.result.name,
        'actionId': result.actionId,
      },
    );
  }

  CorrectionActionType? _actionTypeFromName(String action) {
    switch (action) {
      case 'tap':
        return CorrectionActionType.tap;
      case 'long_press':
        return CorrectionActionType.longPress;
      case 'swipe':
        return CorrectionActionType.swipe;
      case 'type_text':
        return CorrectionActionType.typeText;
      case 'scroll':
        return CorrectionActionType.scroll;
      default:
        return null;
    }
  }

  Map<String, dynamic> _targetToMap(ScreenTarget target) {
    return {
      'targetId': target.targetId,
      'type': target.type,
      'bounds': target.bounds,
      'confidence': target.confidence,
      'label': target.label,
      'verified': target.verified,
      'locale': target.locale,
      'detectedAt': target.detectedAt.toIso8601String(),
      'screenId': target.screenId,
      'actionable': target.isActionable,
    };
  }

  @override
  ToolInput validate(Map<String, dynamic> params) {
    final action = params['action'];

    if (action is! String || !_validActions.contains(action)) {
      return ToolInput.invalid(
        toolId: id,
        rawParams: params,
        field: 'action',
        message: 'Valid actions: ${_validActions.join(", ")}',
      );
    }

    final screenId = params['screenId'];
    if (screenId is! String || screenId.trim().isEmpty) {
      return ToolInput.invalid(
        toolId: id,
        rawParams: params,
        field: 'screenId',
        message: 'screenId is required',
      );
    }

    if (action == 'find' ||
        action == 'tap' ||
        action == 'long_press' ||
        action == 'swipe' ||
        action == 'type_text' ||
        action == 'scroll') {
      final label = params['label'];

      if (label is! String || label.trim().isEmpty) {
        return ToolInput.invalid(
          toolId: id,
          rawParams: params,
          field: 'label',
          message: 'label is required for this action',
        );
      }
    }

    if ((action == 'type_text') &&
        (params['textInput'] is! String ||
            (params['textInput'] as String).isEmpty)) {
      return ToolInput.invalid(
        toolId: id,
        rawParams: params,
        field: 'textInput',
        message: 'textInput is required for type_text',
      );
    }

    if ((action == 'swipe' || action == 'scroll') &&
        (params['swipeDirection'] is! String ||
            (params['swipeDirection'] as String).trim().isEmpty)) {
      return ToolInput.invalid(
        toolId: id,
        rawParams: params,
        field: 'swipeDirection',
        message: 'swipeDirection is required for swipe/scroll',
      );
    }

    return ToolInput.valid(
      toolId: id,
      params: Map<String, dynamic>.from(params),
    );
  }

  @override
  String describe() =>
      'ئامرازی تێگەیشتن لە شاشە و کرداری سەلمێندراو لەسەر target ـەکانی شاشە';

  @override
  bool cancel() => false;
}
