import '../tool.dart';
import '../tool_definition.dart';
import '../../agent/agent_confirmation_manager.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import '../../device/device_channel.dart';
import '../../../core/errors/result.dart';

/// Tool to retrieve device hardware and OS information.
///
/// Reads-only operation (no side effects), so risk level is [none]
/// and no user confirmation is needed.
class DeviceInfoTool extends Tool {
  final DeviceChannel _deviceChannel;

  DeviceInfoTool(this._deviceChannel);

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'device_info',
        description:
            'زانیاری ئامێر و سیستەمی کارپێکردر وەربگرە '
            '(مارکا، مۆدێل، وەشانی ئەندرۆید، ئاستی SDK، و هتد). '
            '— '
            'Get hardware and operating system information about the device '
            '(brand, model, Android version, SDK level, etc.).',
        category: 'device',
        parameters: [],
        permissionRequirements: [],
        isDangerous: false,
        requiresConfirmation: false,
        tags: ['device', 'info', 'hardware', 'system', 'ئامێر', 'زانیاری'],
        icon: 'phone_android',
        timeout: Duration(seconds: 10),
        riskLevel: ToolRiskLevel.none,
      );

  @override
  Future<ToolResult> execute(ToolArguments args) async {
    try {
      final result = await _deviceChannel.getDeviceInfo();

      if (!result.isSuccess) {
        return ToolResult.failure(
          result.errorMessage ?? 'Device info request failed',
          errorCode: result.errorCode,
        );
      }

      return ToolResult.success(result.data);
    } catch (e) {
      return ToolResult.failure(
        'Device info error: $e',
        errorCode: 'internalError',
      );
    }
  }
}
