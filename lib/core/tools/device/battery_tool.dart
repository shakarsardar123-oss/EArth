import '../tool.dart';
import '../tool_definition.dart';
import '../tool_permission.dart';
import '../../agent/agent_confirmation_manager.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import '../../device/device_channel.dart';
import '../../../core/errors/result.dart';

/// Tool to retrieve battery level, charging status, and charging type.
///
/// Read-only operation (no side effects), so risk level is [none]
/// and no user confirmation is needed.
class BatteryTool extends Tool {
  final DeviceChannel _deviceChannel;

  BatteryTool(this._deviceChannel);

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'battery',
        description:
            'زانیاری باتری وەربگرە '
            '(ئاستی باتری، بارکردن، جۆری بارکردن). '
            '— '
            'Get battery information including level, charging status, '
            'and charging type (AC, USB, wireless).',
        category: 'device',
        parameters: [],
        permissionRequirements: [
          ToolPermissionRequirement(
            permission: ToolPermission.battery,
            isRequired: true,
          ),
        ],
        isDangerous: false,
        requiresConfirmation: false,
        tags: ['device', 'battery', 'power', 'charging', 'باتری', 'بارکردن'],
        icon: 'battery_std',
        timeout: Duration(seconds: 10),
        riskLevel: ToolRiskLevel.none,
      );

  @override
  Future<ToolResult> execute(ToolArguments args) async {
    try {
      final result = await _deviceChannel.getBatteryInfo();

      if (!result.isSuccess) {
        return ToolResult.failure(
          result.errorMessage ?? 'Battery info request failed',
          errorCode: result.errorCode,
        );
      }

      return ToolResult.success(result.data);
    } catch (e) {
      return ToolResult.failure(
        'Battery info error: $e',
        errorCode: 'internalError',
      );
    }
  }
}
