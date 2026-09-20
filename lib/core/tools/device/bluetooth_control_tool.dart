/// Phase 6 — Bluetooth Control Tool.
///
/// Reads and toggles the Android Bluetooth adapter state via the
/// [SystemControlChannel] abstraction.
///
/// **Honest version-gating:**
/// * On API >= 33 the direct toggle is a no-op per Google policy; the tool
///   opens the Bluetooth settings panel and truthfully reports
///   `requiresUserAction: true`. It NEVER claims a state change it cannot
///   verify.
/// * On API < 33 (when BLUETOOTH_ADMIN is held) the toggle succeeds
///   directly.
library;

import '../tool.dart';
import '../tool_definition.dart';
import '../tool_permission.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import '../../agent/agent_confirmation_manager.dart';
import '../../device/system_control_channel.dart';
import '../../../core/errors/result.dart';

/// Forbidden patterns to prevent shell injection in any argument string.
const List<String> _forbidden = [
  ';', '&', '|', '`', r'$', '(', ')', '{', '}', '<', '>', '!', '\n', '\r', '\t',
];

class BluetoothControlTool extends Tool {
  final SystemControlChannel _channel;

  BluetoothControlTool(this._channel);

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'bluetooth_control',
        description:
            'دۆخی بلوتوز بخوێنیتەوە یان چالاکی/ناچالاکی بکەیت. '
            '— '
            'Read or toggle the Android Bluetooth adapter state. '
            'On Android 13+ the toggle opens the settings panel instead '
            'of changing the state directly.',
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
                'پێویستە ڕێگەی سیستەم بۆ کۆنترۆڵی بلوتوز. '
                '— '
                'System permission is required for Bluetooth control.',
          ),
        ],
        isDangerous: false,
        requiresConfirmation: true,
        tags: ['device', 'bluetooth', 'toggle', 'بلوتوز'],
        icon: 'bluetooth',
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
          final r = await _channel.getBluetoothState();
          return _resultFromChannel(r);

        case 'enable':
          final r = await _channel.setBluetoothEnabled(true);
          return _resultFromChannel(r);

        case 'disable':
          final r = await _channel.setBluetoothEnabled(false);
          return _resultFromChannel(r);

        default:
          return ToolResult.failure(
            'Unknown action: $action',
            errorCode: 'invalidArguments',
          );
      }
    } catch (e) {
      return ToolResult.failure(
        'Bluetooth error: $e',
        errorCode: 'internalError',
      );
    }
  }

  ToolResult _resultFromChannel(DeviceChannelResult r) {
    if (!r.isSuccess) {
      return ToolResult.failure(
        r.errorMessage ?? 'Bluetooth channel error',
        errorCode: r.errorCode,
      );
    }
    return ToolResult.success(r.data);
  }
}
