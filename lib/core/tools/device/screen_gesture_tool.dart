/// Phase 6 — Screen Gesture Tool.
///
/// Dispatches real on-screen gestures (tap / long-press / swipe) through
/// AURA's [AuraAccessibilityService] via the [SystemControlChannel].
///
/// **Fail-closed:** if the accessibility service is not enabled AND bound,
/// the tool refuses with `accessibilityDisabled` rather than pretending a
/// gesture happened. Coordinates are validated to be non-negative finite
/// numbers. Gesture dispatch requires API 24+, otherwise the native side
/// returns `platformUnsupported`.
///
/// **Risk:** dispatching input events can trigger arbitrary UI actions, so
/// this tool is [ToolRiskLevel.high] and requires user confirmation.
library;

import '../tool.dart';
import '../tool_definition.dart';
import '../tool_permission.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import '../../agent/agent_confirmation_manager.dart';
import '../../device/system_control_channel.dart';
import '../../../core/errors/result.dart';

class ScreenGestureTool extends Tool {
  final SystemControlChannel _channel;

  ScreenGestureTool(this._channel);

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'screen_gesture',
        description:
            'جوڵەی شاشە ئەنجام بدە (پەنجەدان، پەنجەی درێژ، سوایپ) '
            'بە رێگەی خزمەتگوزاری دەستپێگەیشتن. '
            '— '
            'Dispatch a screen gesture (tap, long_press, swipe) through the '
            'AURA accessibility service. Requires the service to be enabled.',
        category: 'device',
        parameters: [
          ToolArgumentDef(
            name: 'gesture',
            type: 'string',
            description: 'Gesture type: tap, long_press, swipe.',
            isRequired: true,
            enumValues: ['tap', 'long_press', 'swipe'],
            example: 'tap',
            label: 'جوڵە',
            hintText: 'tap',
          ),
          ToolArgumentDef(
            name: 'x',
            type: 'double',
            description: 'Start X coordinate in screen pixels.',
            isRequired: true,
            example: 540.0,
            keyboardType: 'number',
          ),
          ToolArgumentDef(
            name: 'y',
            type: 'double',
            description: 'Start Y coordinate in screen pixels.',
            isRequired: true,
            example: 1200.0,
            keyboardType: 'number',
          ),
          ToolArgumentDef(
            name: 'x2',
            type: 'double',
            description: 'End X coordinate (swipe only).',
            isRequired: false,
            keyboardType: 'number',
          ),
          ToolArgumentDef(
            name: 'y2',
            type: 'double',
            description: 'End Y coordinate (swipe only).',
            isRequired: false,
            keyboardType: 'number',
          ),
          ToolArgumentDef(
            name: 'durationMs',
            type: 'int',
            description: 'Gesture stroke duration in milliseconds.',
            isRequired: false,
            defaultValue: 150,
            minValue: 10,
            maxValue: 10000,
            keyboardType: 'number',
          ),
        ],
        permissionRequirements: [
          ToolPermissionRequirement(
            permission: ToolPermission.system,
            isRequired: true,
            rationale:
                'پێویستە خزمەتگوزاری دەستپێگەیشتن چالاک بێت بۆ جوڵەی شاشە. '
                '— '
                'The accessibility service must be enabled to dispatch gestures.',
          ),
        ],
        isDangerous: true,
        requiresConfirmation: true,
        tags: ['device', 'gesture', 'accessibility', 'tap', 'swipe', 'جوڵە'],
        icon: 'touch_app',
        timeout: Duration(seconds: 15),
        riskLevel: ToolRiskLevel.high,
      );

  @override
  String? validateArguments(ToolArguments arguments) {
    final gesture = arguments.getString('gesture');
    if (gesture == null || !['tap', 'long_press', 'swipe'].contains(gesture)) {
      return 'gesture must be tap, long_press, or swipe.';
    }
    final x = arguments.getDouble('x') ??
        arguments.getInt('x')?.toDouble();
    final y = arguments.getDouble('y') ??
        arguments.getInt('y')?.toDouble();
    if (x == null || y == null) {
      return 'x and y are required numeric coordinates.';
    }
    if (!x.isFinite || !y.isFinite || x < 0 || y < 0) {
      return 'x and y must be finite non-negative numbers.';
    }
    if (gesture == 'swipe') {
      final x2 = arguments.getDouble('x2') ?? arguments.getInt('x2')?.toDouble();
      final y2 = arguments.getDouble('y2') ?? arguments.getInt('y2')?.toDouble();
      if (x2 == null || y2 == null) {
        return 'swipe requires end coordinates x2 and y2.';
      }
      if (!x2.isFinite || !y2.isFinite || x2 < 0 || y2 < 0) {
        return 'x2 and y2 must be finite non-negative numbers.';
      }
    }
    return null;
  }

  @override
  Future<ToolResult> execute(ToolArguments arguments) async {
    final validationError = validateArguments(arguments);
    if (validationError != null) {
      return ToolResult.failure(validationError, errorCode: 'invalidArguments');
    }

    final gesture = arguments.getString('gesture')!;
    final x = (arguments.getDouble('x') ?? arguments.getInt('x')!.toDouble());
    final y = (arguments.getDouble('y') ?? arguments.getInt('y')!.toDouble());
    final x2 = arguments.getDouble('x2') ?? arguments.getInt('x2')?.toDouble();
    final y2 = arguments.getDouble('y2') ?? arguments.getInt('y2')?.toDouble();
    final durationMs = arguments.getOrElse<int>('durationMs', 150);

    try {
      // Fail-closed pre-check: verify the service is actually bound before
      // attempting a gesture, so we never claim a dispatch we cannot make.
      final avail = await _channel.isAccessibilityServiceEnabled();
      if (!avail.isSuccess) {
        return ToolResult.failure(
          avail.errorMessage ?? 'Accessibility check failed',
          errorCode: avail.errorCode,
        );
      }
      final enabled = (avail.data?['enabled'] as bool?) ?? false;
      if (!enabled) {
        return const ToolResult.failure(
          'خزمەتگوزاری دەستپێگەیشتن چالاک نییە. '
          '— The accessibility service is not enabled.',
          errorCode: 'accessibilityDisabled',
        );
      }

      final r = await _channel.dispatchGesture(
        gesture: gesture,
        x: x,
        y: y,
        x2: x2,
        y2: y2,
        durationMs: durationMs,
      );
      if (!r.isSuccess) {
        return ToolResult.failure(
          r.errorMessage ?? 'Gesture dispatch failed',
          errorCode: r.errorCode,
        );
      }
      final data = Map<String, dynamic>.from(r.data ?? {});
      data['gesture'] = gesture;
      return ToolResult.success(data);
    } catch (e) {
      return ToolResult.failure(
        'Gesture error: $e',
        errorCode: 'internalError',
      );
    }
  }
}
