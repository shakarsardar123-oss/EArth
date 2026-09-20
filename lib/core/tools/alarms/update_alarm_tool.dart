import '../../../domain/entities/alarm/wake_alarm.dart';
import '../../../domain/entities/alarm/wake_verification_config.dart';
import '../tool.dart';
import '../tool_definition.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import 'alarm_tool_gateway.dart';
import '../../../core/errors/result.dart';

/// Tool to update an existing wake verification alarm.
class UpdateAlarmTool extends Tool {
  UpdateAlarmTool(this._gateway);

  final AlarmToolGateway _gateway;

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'update_alarm',
        description: 'Update settings of an existing alarm such as time, label, verification mode, or repeat days.',
        category: 'alarms',
        parameters: [
          ToolArgumentDef(
            name: 'alarm_id',
            type: 'string',
            description: 'The unique ID of the alarm to update',
            isRequired: true,
          ),
          ToolArgumentDef(
            name: 'hour',
            type: 'int',
            description: 'New hour (0-23)',
            isRequired: false,
          ),
          ToolArgumentDef(
            name: 'minute',
            type: 'int',
            description: 'New minute (0-59)',
            isRequired: false,
          ),
          ToolArgumentDef(
            name: 'label',
            type: 'string',
            description: 'New label for the alarm',
            isRequired: false,
          ),
          ToolArgumentDef(
            name: 'enabled',
            type: 'bool',
            description: 'Enable or disable the alarm',
            isRequired: false,
          ),
          ToolArgumentDef(
            name: 'verification_mode',
            type: 'string',
            description: 'New verification mode: none, voice, face, combined',
            isRequired: false,
            enumValues: ['none', 'voice', 'face', 'combined'],
          ),
          ToolArgumentDef(
            name: 'repeat_days',
            type: 'list',
            itemType: 'int',
            description: 'New repeat days (1=Mon, 7=Sun). Empty for one-shot.',
            isRequired: false,
          ),
          ToolArgumentDef(
            name: 'snooze_duration_minutes',
            type: 'int',
            description: 'New snooze duration in minutes',
            isRequired: false,
            minValue: 1,
            maxValue: 30,
          ),
        ],
      );

  @override
  Future<ToolResult> execute(ToolArguments args) async {
    final alarmId = args.get<String>('alarm_id');

    if (alarmId.isEmpty) {
      return const ToolResult.failure('alarm_id is required');
    }

    final updates = <String, dynamic>{};
    if (args.has('hour')) updates['hour'] = args.get<int>('hour');
    if (args.has('minute')) updates['minute'] = args.get<int>('minute');
    if (args.has('label')) updates['label'] = args.get<String>('label');
    if (args.has('enabled')) updates['enabled'] = args.get<bool>('enabled');
    if (args.has('verification_mode')) {
      updates['verification_mode'] = args.get<String>('verification_mode');
    }
    if (args.has('repeat_days')) {
      updates['repeat_days'] = args.getOrElse<List<dynamic>>('repeat_days', []).cast<int>();
    }
    if (args.has('snooze_duration_minutes')) {
      final val = args.get<int>('snooze_duration_minutes');
      if (val < 1 || val > 30) {
        return ToolResult.failure('snooze_duration_minutes must be 1-30, got $val');
      }
      updates['snooze_duration_minutes'] = val;
    }

    if (updates.isEmpty) {
      return const ToolResult.failure('No fields provided to update');
    }

    final existing = await _gateway.findAlarm(alarmId);
    if (existing == null) {
      return ToolResult.failure(
        'No alarm exists with id "$alarmId".',
        errorCode: 'ALARM_NOT_FOUND',
      );
    }

    var updated = existing;
    if (updates.containsKey('hour') || updates.containsKey('minute')) {
      updated = updated.copyWith(
        time: TimeOfDayData(
          hour: updates['hour'] as int? ?? existing.time.hour,
          minute: updates['minute'] as int? ?? existing.time.minute,
        ),
      );
    }
    if (updates.containsKey('label')) {
      updated = updated.copyWith(label: updates['label'] as String);
    }
    if (updates.containsKey('enabled')) {
      updated = updated.copyWith(enabled: updates['enabled'] as bool);
    }
    if (updates.containsKey('repeat_days')) {
      updated = updated.copyWith(
        repeatDays: (updates['repeat_days'] as List).cast<int>(),
      );
    }
    if (updates.containsKey('verification_mode')) {
      final modeStr = updates['verification_mode'] as String;
      final mode = WakeVerificationMode.values.firstWhere(
        (e) => e.name == modeStr,
        orElse: () => existing.verificationConfig.mode,
      );
      updated = updated.copyWith(
        verificationConfig:
            updated.verificationConfig.copyWith(mode: mode),
      );
    }
    if (updates.containsKey('snooze_duration_minutes')) {
      final snooze = updates['snooze_duration_minutes'] as int;
      updated = updated.copyWith(
        snoozeDurationMinutes: snooze,
        verificationConfig: updated.verificationConfig
            .copyWith(snoozeDurationMinutes: snooze),
      );
    }

    final applied = await _gateway.updateAlarm(updated);
    if (!applied) {
      return ToolResult.failure(
        'Failed to re-schedule alarm "$alarmId" after update. '
        'No changes were applied.',
        errorCode: 'ALARM_UPDATE_FAILED',
      );
    }

    return ToolResult.success({
      'alarm_id': alarmId,
      'alarm': updated.toJson(),
      'updates': updates,
      'message':
          'Alarm $alarmId updated: ${updates.keys.join(', ')}',
    });
  }
}
