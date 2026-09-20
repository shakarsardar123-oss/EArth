import '../../../domain/entities/alarm/wake_alarm.dart';
import '../../../domain/entities/alarm/wake_verification_config.dart';
import '../tool.dart';
import '../tool_definition.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import 'alarm_tool_gateway.dart';
import '../../../core/errors/result.dart';

/// Tool to create a new wake verification alarm.
class CreateAlarmTool extends Tool {
  CreateAlarmTool(this._gateway);

  final AlarmToolGateway _gateway;

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'create_alarm',
        description: 'Create a new wake verification alarm with a specified time, label, and optional verification settings.',
        category: 'alarms',
        parameters: [
          ToolArgumentDef(
            name: 'hour',
            type: 'int',
            description: 'Hour of the alarm (0-23)',
            isRequired: true,
            minValue: 0,
            maxValue: 23,
          ),
          ToolArgumentDef(
            name: 'minute',
            type: 'int',
            description: 'Minute of the alarm (0-59)',
            isRequired: true,
            minValue: 0,
            maxValue: 59,
          ),
          ToolArgumentDef(
            name: 'label',
            type: 'string',
            description: 'Label/name for the alarm',
            isRequired: false,
            defaultValue: '',
          ),
          ToolArgumentDef(
            name: 'verification_mode',
            type: 'string',
            description: 'Verification mode: none, voice, face, combined',
            isRequired: false,
            defaultValue: 'none',
            enumValues: ['none', 'voice', 'face', 'combined'],
          ),
          ToolArgumentDef(
            name: 'repeat_days',
            type: 'list',
            itemType: 'int',
            description: 'List of repeat day numbers (1=Mon, 7=Sun). Empty for one-shot.',
            isRequired: false,
            defaultValue: [],
          ),
          ToolArgumentDef(
            name: 'snooze_duration_minutes',
            type: 'int',
            description: 'Snooze duration in minutes',
            isRequired: false,
            defaultValue: 5,
            minValue: 1,
            maxValue: 30,
          ),
        ],
      );

  @override
  Future<ToolResult> execute(ToolArguments args) async {
    final hour = args.get<int>('hour');
    final minute = args.get<int>('minute');
    final label = args.getOrElse<String>('label', '');
    final modeStr = args.getOrElse<String>('verification_mode', 'none');
    final repeatDays = args.getOrElse<List<dynamic>>('repeat_days', [])
        .cast<int>();
    final snoozeDuration = args.getOrElse<int>('snooze_duration_minutes', 5);

    // Validate.
    if (hour < 0 || hour > 23) {
      return ToolResult.failure('hour must be 0-23, got $hour');
    }
    if (minute < 0 || minute > 59) {
      return ToolResult.failure('minute must be 0-59, got $minute');
    }

    final mode = WakeVerificationMode.values.firstWhere(
      (e) => e.name == modeStr,
      orElse: () => WakeVerificationMode.none,
    );

    final alarm = WakeAlarm(
      id: 'alarm_${DateTime.now().millisecondsSinceEpoch}',
      time: TimeOfDayData(hour: hour, minute: minute),
      label: label,
      enabled: true,
      repeatDays: repeatDays,
      verificationConfig: WakeVerificationConfig(
        mode: mode,
        snoozeDurationMinutes: snoozeDuration,
      ),
      snoozeDurationMinutes: snoozeDuration,
    );

    final created = await _gateway.createAlarm(alarm);
    if (!created) {
      return ToolResult.failure(
        'Failed to schedule alarm at ${alarm.time.formatted}. '
        'The alarm was not created (scheduling was rejected by the system).',
        errorCode: 'ALARM_SCHEDULE_FAILED',
      );
    }

    return ToolResult.success({
      'alarm': alarm.toJson(),
      'message': 'Alarm created: ${alarm.time.formatted} - ${alarm.label}',
    });
  }
}
