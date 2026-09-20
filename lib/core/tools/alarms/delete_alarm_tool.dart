import '../tool.dart';
import '../tool_definition.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import 'alarm_tool_gateway.dart';
import '../../../core/errors/result.dart';

/// Tool to delete a wake verification alarm.
class DeleteAlarmTool extends Tool {
  DeleteAlarmTool(this._gateway);

  final AlarmToolGateway _gateway;

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'delete_alarm',
        description: 'Delete an existing wake verification alarm by its ID.',
        category: 'alarms',
        parameters: [
          ToolArgumentDef(
            name: 'alarm_id',
            type: 'string',
            description: 'The unique ID of the alarm to delete',
            isRequired: true,
          ),
        ],
      );

  @override
  Future<ToolResult> execute(ToolArguments args) async {
    final alarmId = args.get<String>('alarm_id');

    if (alarmId.isEmpty) {
      return const ToolResult.failure('alarm_id is required');
    }

    final existing = await _gateway.findAlarm(alarmId);
    if (existing == null) {
      return ToolResult.failure(
        'No alarm exists with id "$alarmId".',
        errorCode: 'ALARM_NOT_FOUND',
      );
    }

    final deleted = await _gateway.deleteAlarm(alarmId);
    if (!deleted) {
      return ToolResult.failure(
        'Failed to cancel and delete alarm "$alarmId".',
        errorCode: 'ALARM_DELETE_FAILED',
      );
    }

    return ToolResult.success({
      'alarm_id': alarmId,
      'action': 'delete',
      'message': 'Alarm $alarmId deleted.',
    });
  }
}
