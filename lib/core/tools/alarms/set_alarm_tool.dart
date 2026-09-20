import '../../../domain/entities/alarm/wake_alarm.dart';
import '../tool.dart';
import '../tool_definition.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import 'alarm_tool_gateway.dart';
import '../../../core/errors/result.dart';

/// Tool to quickly set a one-shot alarm using natural language input.
/// Simplified interface compared to CreateAlarmTool for voice/chat use.
class SetAlarmTool extends Tool {
  SetAlarmTool(this._gateway);

  final AlarmToolGateway _gateway;

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'set_alarm',
        description: 'Quickly set a one-shot alarm by specifying time and optional label. '
            'Use this for simple voice or chat requests like "set alarm for 7:30" '
            'or "wake me up at 6". For advanced options use create_alarm instead.',
        category: 'alarms',
        parameters: [
          ToolArgumentDef(
            name: 'time',
            type: 'string',
            description: 'Time in HH:MM format (24h) or natural language like "7:30" or "6 am"',
            isRequired: true,
          ),
          ToolArgumentDef(
            name: 'label',
            type: 'string',
            description: 'Optional label for the alarm',
            isRequired: false,
            defaultValue: '',
          ),
        ],
      );

  @override
  Future<ToolResult> execute(ToolArguments args) async {
    final timeStr = args.get<String>('time');
    final label = args.getOrElse<String>('label', '');

    if (timeStr.isEmpty) {
      return const ToolResult.failure('time is required');
    }

    // Parse HH:MM or HH:MM AM/PM patterns.
    int? hour;
    int? minute;

    // Try HH:MM format.
    final hHmmMatch = RegExp(r'^(\d{1,2}):(\d{2})\s*(am|pm)?$',
            caseSensitive: false)
        .firstMatch(timeStr);
    if (hHmmMatch != null) {
      hour = int.tryParse(hHmmMatch.group(1)!);
      minute = int.tryParse(hHmmMatch.group(2)!);
      final ampm = hHmmMatch.group(3)?.toLowerCase();
      if (ampm == 'pm' && hour != null && hour < 12) {
        hour += 12;
      } else if (ampm == 'am' && hour == 12) {
        hour = 0;
      }
    } else {
      // Try just a number like "6" or "7 am".
      final simpleMatch = RegExp(r'^(\d{1,2})\s*(am|pm)?$',
              caseSensitive: false)
          .firstMatch(timeStr);
      if (simpleMatch != null) {
        hour = int.tryParse(simpleMatch.group(1)!);
        minute = 0;
        final ampm = simpleMatch.group(2)?.toLowerCase();
        if (ampm == 'pm' && hour != null && hour < 12) {
          hour += 12;
        } else if (ampm == 'am' && hour == 12) {
          hour = 0;
        }
      }
    }

    if (hour == null || minute == null) {
      return ToolResult.failure(
          'Could not parse time "$timeStr". Use HH:MM format like "7:30" or "19:00".');
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return ToolResult.failure('Invalid time: $hour:$minute.');
    }

    final alarm = WakeAlarm(
      id: 'alarm_${DateTime.now().millisecondsSinceEpoch}',
      time: TimeOfDayData(hour: hour, minute: minute),
      label: label,
      enabled: true,
    );

    final created = await _gateway.createAlarm(alarm);
    if (!created) {
      return ToolResult.failure(
        'Failed to schedule alarm for ${alarm.time.formatted}. '
        'The alarm was not set (scheduling was rejected by the system).',
        errorCode: 'ALARM_SCHEDULE_FAILED',
      );
    }

    return ToolResult.success({
      'alarm': alarm.toJson(),
      'hour': hour,
      'minute': minute,
      'label': label,
      'message': 'Alarm set for ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}${label.isNotEmpty ? ' - $label' : ''}',
    });
  }
}
