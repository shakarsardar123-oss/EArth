/// Riverpod-backed implementation of [AlarmToolGateway].
///
/// Bridges the agent's alarm tools to the real [AlarmSchedulerService]
/// (platform scheduling + SharedPreferences persistence) and keeps the
/// in-app alarm list state in sync so UI and agent never diverge.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/alarm/alarm_scheduler_service.dart';
import '../../core/tools/alarms/alarm_tool_gateway.dart';
import '../../domain/entities/alarm/wake_alarm.dart';
import 'alarm_providers.dart' show alarmListProvider;

class RiverpodAlarmToolGateway implements AlarmToolGateway {
  RiverpodAlarmToolGateway(this._ref, this._scheduler);

  final Ref _ref;
  final AlarmSchedulerService _scheduler;

  @override
  Future<List<WakeAlarm>> listAlarms() => _scheduler.loadAlarms();

  @override
  Future<WakeAlarm?> findAlarm(String alarmId) async {
    final alarms = await _scheduler.loadAlarms();
    for (final alarm in alarms) {
      if (alarm.id == alarmId) return alarm;
    }
    return null;
  }

  @override
  Future<bool> createAlarm(WakeAlarm alarm) async {
    final scheduled = alarm.repeatDays.isEmpty
        ? await _scheduler.scheduleAlarm(alarm)
        : await _scheduler.scheduleRepeatingAlarm(alarm);
    if (!scheduled) return false;
    _syncList();
    return true;
  }

  @override
  Future<bool> updateAlarm(WakeAlarm alarm) async {
    await _scheduler.cancelAlarm(alarm.id);
    if (!alarm.enabled) {
      // A disabled alarm is persisted-as-cancelled; that is a real outcome.
      _syncList();
      return true;
    }
    final scheduled = alarm.repeatDays.isEmpty
        ? await _scheduler.scheduleAlarm(alarm)
        : await _scheduler.scheduleRepeatingAlarm(alarm);
    if (!scheduled) return false;
    _syncList();
    return true;
  }

  @override
  Future<bool> deleteAlarm(String alarmId) async {
    final cancelled = await _scheduler.cancelAlarm(alarmId);
    if (!cancelled) return false;
    _syncList();
    return true;
  }

  /// Refresh the UI-facing alarm list from persisted state.
  void _syncList() {
    try {
      _ref.read(alarmListProvider.notifier).init();
    } catch (_) {
      // The list provider may not be alive (e.g. headless/agent-only use);
      // persistence already happened, so this is not a failure.
    }
  }
}

/// Provider for the alarm tool gateway.
final alarmToolGatewayProvider = Provider<AlarmToolGateway>((ref) {
  return RiverpodAlarmToolGateway(ref, ref.watch(alarmSchedulerProvider));
});
