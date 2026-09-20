/// Gateway that connects the alarm tools to the real alarm subsystem.
///
/// The tools themselves must never fabricate success: every method here is
/// backed by [AlarmSchedulerService] (platform alarm scheduling + persistence)
/// and returns the real outcome, so a failing schedule/cancel surfaces to the
/// agent as a tool failure.
library;

import '../../../domain/entities/alarm/wake_alarm.dart';

abstract class AlarmToolGateway {
  /// All persisted alarms.
  Future<List<WakeAlarm>> listAlarms();

  /// Look up a single alarm by id, or `null` when it does not exist.
  Future<WakeAlarm?> findAlarm(String alarmId);

  /// Persist and schedule [alarm]. Returns `true` only when the platform
  /// alarm was really scheduled.
  Future<bool> createAlarm(WakeAlarm alarm);

  /// Re-persist and re-schedule [alarm]. Returns the real outcome.
  Future<bool> updateAlarm(WakeAlarm alarm);

  /// Cancel and delete the alarm with [alarmId]. Returns the real outcome.
  Future<bool> deleteAlarm(String alarmId);
}
