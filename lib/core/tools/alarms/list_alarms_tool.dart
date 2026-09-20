import '../tool.dart';
import '../tool_definition.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import 'alarm_tool_gateway.dart';
import '../../../core/errors/result.dart';

/// Tool to list all wake verification alarms.
class ListAlarmsTool extends Tool {
  ListAlarmsTool(this._gateway);

  final AlarmToolGateway _gateway;

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'list_alarms',
        description: 'List all configured wake verification alarms with their times, labels, and verification modes.',
        category: 'alarms',
        parameters: [
          ToolArgumentDef(
            name: 'enabled_only',
            type: 'bool',
            description: 'If true, only return enabled alarms',
            isRequired: false,
            defaultValue: false,
          ),
        ],
      );

  @override
  Future<ToolResult> execute(ToolArguments args) async {
    final enabledOnly = args.getOrElse<bool>('enabled_only', false);

    // Read the real persisted alarms from the alarm subsystem.
    final List<dynamic> alarms;
    try {
      final loaded = await _gateway.listAlarms();
      alarms = [
        for (final alarm in loaded)
          if (!enabledOnly || alarm.enabled) alarm.toJson(),
      ];
    } catch (e) {
      return ToolResult.failure(
        'Failed to read alarms from storage: $e',
        errorCode: 'ALARM_READ_FAILED',
      );
    }

    return ToolResult.success({
      'alarms': alarms,
      'count': alarms.length,
      'enabled_only': enabledOnly,
      'message': alarms.isEmpty
          ? 'No alarms are configured.'
          : '${alarms.length} alarm(s) configured.',
    });
  }
}
