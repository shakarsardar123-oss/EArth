/// Phase 6 — Wi-Fi Control Tool.
///
/// Reads and toggles the Android Wi-Fi state via the
/// [SystemControlChannel] abstraction.
///
/// **Honest version-gating:** `WifiManager.setWifiEnabled` is a hard no-op
/// on API 29+ by OS policy. On those releases the tool opens the Wi-Fi
/// settings panel and truthfully returns `requiresUserAction: true`. It
/// never reports a state change it cannot verify.
library;

import '../tool.dart';
import '../tool_definition.dart';
import '../tool_permission.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import '../../agent/agent_confirmation_manager.dart';
import '../../device/system_control_channel.dart';
import '../../../core/errors/result.dart';

const List<String> _forbidden = [
  ';', '&', '|', '`', r'$', '(', ')', '{', '}', '<', '>', '!', '\n', '\r', '\t',
];

class WifiControlTool extends Tool {
  final SystemControlChannel _channel;

  WifiControlTool(this._channel);

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'wifi_control',
        description:
            'دۆخی وایفای بخوێنیتەوە یان چالاکی/ناچالاکی بکەیت. '
            '— '
            'Read or toggle the Android Wi-Fi state. On Android 10+ the '
            'toggle opens the Wi-Fi settings panel instead of changing '
            'the state directly.',
        category: 'device',
        parameters: [
          ToolArgumentDef(
            name: 'action',
            type: 'string',
            description:
                'کردار: state (خوێندنەوە), enable (چالاکی), disable (ناچالاکی). '
                '— '
                'Action: state (read), enable, disable.',
            isRequired: true,
            enumValues: ['state', 'enable', 'disable'],
            example: 'state',
            label: 'کردار',
            hintText: 'state',
          ),
        ],
        permissionRequirements: [
          ToolPermissionRequirement(
            permission: ToolPermission.system,
            isRequired: true,
            rationale:
                'پێویستە ڕێگەی سیستەم بۆ کۆنترۆڵی وایفای. '
                '— '
                'System permission is required for Wi-Fi control.',
          ),
        ],
        isDangerous: false,
        requiresConfirmation: true,
        tags: ['device', 'wifi', 'toggle', 'وایفای'],
        icon: 'wifi',
        timeout: Duration(seconds: 15),
        riskLevel: ToolRiskLevel.medium,
      );

  @override
  String? validateArguments(ToolArguments arguments) {
    final action = arguments.getString('action');
    if (action == null || action.isEmpty) {
      return 'action is required. — کردار پێویستە.';
    }
    if (!['state', 'enable', 'disable'].contains(action)) {
      return 'action must be state, enable, or disable. '
          '— کردار دەبێت state یان enable یان disable بێت.';
    }
    for (final p in _forbidden) {
      if (action.contains(p)) {
        return 'action contains forbidden character "$p".';
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

    final action = arguments.getString('action')!;

    try {
      switch (action) {
        case 'state':
          return _resultFromChannel(await _channel.getWifiState());
        case 'enable':
          return _resultFromChannel(await _channel.setWifiEnabled(true));
        case 'disable':
          return _resultFromChannel(await _channel.setWifiEnabled(false));
        default:
          return ToolResult.failure(
            'Unknown action: $action',
            errorCode: 'invalidArguments',
          );
      }
    } catch (e) {
      return ToolResult.failure('Wi-Fi error: $e', errorCode: 'internalError');
    }
  }

  ToolResult _resultFromChannel(DeviceChannelResult r) {
    if (!r.isSuccess) {
      return ToolResult.failure(
        r.errorMessage ?? 'Wi-Fi channel error',
        errorCode: r.errorCode,
      );
    }
    return ToolResult.success(r.data);
  }
}
