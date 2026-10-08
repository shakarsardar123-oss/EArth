import '../agent/agent_confirmation_manager.dart';
import '../tools/tool.dart';
import '../tools/tool_arguments.dart';
import '../tools/tool_definition.dart';
import '../tools/tool_permission.dart';
import '../tools/tool_result.dart';
import '../../features/screen_target/application/screen_target_orchestrator.dart';
import '../../features/screen_target/domain/models/correction_action.dart';

class ScreenTargetCoreTool extends Tool {
  ScreenTargetCoreTool(this._orchestrator);

  final ScreenTargetOrchestrator _orchestrator;

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'screen_target',
        description:
            'تێگەیشتن لە شاشە، دۆزینەوەی target ـە بینراوەکان، '
            'و ئەنجامدانی کرداری سەلمێندراو لەسەر شاشە. '
            '— Understand the current screen, find visible targets, '
            'and perform verified screen actions.',
        category: 'screen',
        parameters: [
          ToolArgumentDef(
            name: 'action',
            type: 'string',
            description:
                'Action: scan, find, tap, long_press, swipe, type_text, scroll.',
            enumValues: [
              'scan',
              'find',
              'tap',
              'long_press',
              'swipe',
              'type_text',
              'scroll',
            ],
            example: 'scan',
          ),
          ToolArgumentDef(
            name: 'screenId',
            type: 'string',
            description: 'Identifier of the screen to understand.',
            example: 'current_screen',
          ),
          ToolArgumentDef(
            name: 'label',
            type: 'string',
            description: 'Visible target label for find/action operations.',
            isRequired: false,
          ),
          ToolArgumentDef(
            name: 'textInput',
            type: 'string',
            description: 'Text to enter for type_text.',
            isRequired: false,
          ),
          ToolArgumentDef(
            name: 'swipeDirection',
            type: 'string',
            description: 'Swipe or scroll direction.',
            isRequired: false,
            enumValues: ['up', 'down', 'left', 'right'],
          ),
          ToolArgumentDef(
            name: 'verifyTargets',
            type: 'bool',
            description: 'Whether detected targets must be verified.',
            isRequired: false,
            defaultValue: true,
          ),
        ],
        permissionRequirements: [
          ToolPermissionRequirement(
            permission: ToolPermission.system,
            isRequired: true,
            rationale:
                'پێویستە مۆڵەتی تێگەیشتن و کرداری شاشە هەبێت. '
                '— Screen understanding and action permission is required.',
          ),
        ],
        isDangerous: true,
        requiresConfirmation: true,
        tags: [
          'screen',
          'vision',
          'understanding',
          'target',
          'tap',
          'scroll',
          'type',
        ],
        icon: 'ads_click',
        timeout: Duration(seconds: 15),
        riskLevel: ToolRiskLevel.high,
      );

  @override
  String? validateArguments(ToolArguments arguments) {
    final action = arguments.getString('action');
    const validActions = {
      'scan',
      'find',
      'tap',
      'long_press',
      'swipe',
      'type_text',
      'scroll',
    };

    if (action == null || !validActions.contains(action)) {
      return 'action is invalid.';
    }

    final screenId = arguments.getString('screenId');
    if (screenId == null || screenId.trim().isEmpty) {
      return 'screenId is required.';
    }

    if (action != 'scan') {
      final label = arguments.getString('label');
      if (label == null || label.trim().isEmpty) {
        return 'label is required for this action.';
      }
    }

    if (action == 'type_text') {
      final text = arguments.getString('textInput');
      if (text == null || text.isEmpty) {
        return 'textInput is required for type_text.';
      }
    }

    if (action == 'swipe' || action == 'scroll') {
      final direction = arguments.getString('swipeDirection');
      if (direction == null ||
          !const {'up', 'down', 'left', 'right'}.contains(direction)) {
        return 'swipeDirection must be up, down, left, or right.';
      }
    }

    return null;
  }

  @override
  Future<ToolResult> execute(ToolArguments arguments) async {
    final validationError = validateArguments(arguments);
    if (validationError != null) {
      return ToolResult.failure(
        validationError,
        errorCode: 'invalidArguments',
      );
    }

    final action = arguments.getString('action')!;
    final screenId = arguments.getString('screenId')!.trim();

    try {
      if (action == 'scan') {
        final verdict = await _orchestrator.scanScreen(
          screenId: screenId,
          verifyTargets: arguments.getOrElse<bool>('verifyTargets', true),
        );

        if (!verdict.isAllowed) {
          return ToolResult.failure(
            'Screen scan denied: ${verdict.name}',
            errorCode: verdict.name,
          );
        }

        final result = await _orchestrator.getLatestResult(screenId);

        return ToolResult.success({
          'action': 'scan',
          'screenId': result.screenId,
          'resultId': result.resultId,
          'status': result.status.name,
          'locale': result.locale,
          'verifiedCount': result.verifiedCount,
          'actionableCount': result.actionableCount,
          'targets': result.targets.map((target) => {
                'targetId': target.targetId,
                'type': target.type,
                'label': target.label,
                'confidence': target.confidence,
                'verified': target.verified,
                'actionable': target.isActionable,
                'bounds': target.bounds,
              }).toList(),
        });
      }

      final label = arguments.getString('label')!.trim();

      final target = await _orchestrator.findByLabel(
        screenId: screenId,
        label: label,
      );

      if (!target.verified || !target.isActionable) {
        return const ToolResult.failure(
          'Target was not verified or actionable.',
          errorCode: 'target_not_verified',
        );
      }

      final actionType = switch (action) {
        'tap' => CorrectionActionType.tap,
        'long_press' => CorrectionActionType.longPress,
        'swipe' => CorrectionActionType.swipe,
        'type_text' => CorrectionActionType.typeText,
        'scroll' => CorrectionActionType.scroll,
        _ => null,
      };

      if (actionType == null) {
        return const ToolResult.failure(
          'Unsupported screen action.',
          errorCode: 'unsupportedAction',
        );
      }

      final plan = await _orchestrator.planAction(
        target: target,
        actionType: actionType,
        textInput: arguments.getString('textInput'),
        swipeDirection: arguments.getString('swipeDirection'),
      );

      if (!plan.isAllowed) {
        return ToolResult.failure(
          'Screen action denied: ${plan.name}',
          errorCode: plan.name,
        );
      }

      final planned = CorrectionAction(
        actionId: 'aura-${DateTime.now().microsecondsSinceEpoch}',
        target: target,
        actionType: actionType,
        textInput: arguments.getString('textInput') ?? '',
        swipeDirection: arguments.getString('swipeDirection') ?? '',
        targetVerified: target.verified,
        result: CorrectionResult.unknown,
        executedAt: DateTime.now(),
        locale: target.locale,
      );

      final result = await _orchestrator.executeAction(planned);

      if (!result.result.isSuccess) {
        return ToolResult.failure(
          'Screen action failed: ${result.result.name}',
          errorCode: result.result.name,
        );
      }

      return ToolResult.success({
        'action': action,
        'screenId': screenId,
        'targetId': result.target.targetId,
        'label': result.target.label,
        'result': result.result.name,
        'actionId': result.actionId,
      });
    } catch (e) {
      return ToolResult.failure(
        'Screen-target execution failed.',
        errorCode: 'screenTargetExecutionFailed',
      );
    }
  }
}
