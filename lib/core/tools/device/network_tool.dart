import '../tool.dart';
import '../tool_definition.dart';
import '../tool_permission.dart';
import '../../agent/agent_confirmation_manager.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import '../../device/device_channel.dart';
import '../../../core/errors/result.dart';

/// Tool to retrieve network connectivity information.
///
/// Read-only operation (no side effects), so risk level is [none]
/// and no user confirmation is needed.
///
/// Returns structured data from [DeviceChannel.getNetworkInfo]:
/// - `isConnected` (bool): whether the device has network access
/// - `type` (String): connection type — `wifi`, `mobile`, `ethernet`,
///   `none`, or `unknown`
/// - `networkName` (String?): network name when available
///
/// No sensitive data (passwords, credentials, tokens) is collected.
class NetworkTool extends Tool {
  final DeviceChannel _deviceChannel;

  NetworkTool(this._deviceChannel);

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'network',
        description:
            'زانیاری تۆڕ وەربگرە '
            '(پەیوەندی، جۆری کۆنتێکت، Wi-Fi یان داتا). '
            '— '
            'Get network connectivity information including '
            'connection status, type (Wi-Fi, mobile data), and network name.',
        category: 'device',
        parameters: [],
        permissionRequirements: [
          ToolPermissionRequirement(
            permission: ToolPermission.network,
            isRequired: true,
          ),
        ],
        isDangerous: false,
        requiresConfirmation: false,
        tags: [
          'device',
          'network',
          'connectivity',
          'wifi',
          'تۆڕ',
          'ئینتەرنێت',
          'پەیوەندی',
        ],
        icon: 'wifi',
        timeout: Duration(seconds: 10),
        riskLevel: ToolRiskLevel.none,
      );

  @override
  Future<ToolResult> execute(ToolArguments args) async {
    try {
      final result = await _deviceChannel.getNetworkInfo();

      if (!result.isSuccess) {
        return ToolResult.failure(
          result.errorMessage ?? 'Network info request failed',
          errorCode: result.errorCode,
        );
      }

      return ToolResult.success(result.data);
    } catch (e) {
      return ToolResult.failure(
        'Network info error: $e',
        errorCode: 'internalError',
      );
    }
  }
}
