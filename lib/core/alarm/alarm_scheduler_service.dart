import 'dart:convert';
import 'dart:math';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/alarm/wake_alarm.dart';

/// Provider for AlarmSchedulerService.
final alarmSchedulerProvider = Provider<AlarmSchedulerService>((ref) {
  return AlarmSchedulerService();
});

/// Service responsible for scheduling/canceling alarms using
/// android_alarm_manager_plus and persisting alarm data via SharedPreferences.
class AlarmSchedulerService {
  static const _alarmsKey = 'wake_alarms';
  static const _alarmIdMapKey = 'alarm_id_map';
  static const _pendingAlarmIdKey = 'pending_alarm_id';

  /// Initialize android_alarm_manager. Must call before any scheduling.
  Future<void> init() async {
    await AndroidAlarmManager.initialize();
  }

  /// Schedule a wake alarm. Returns true on success.
  Future<bool> scheduleAlarm(WakeAlarm alarm) async {
    if (!alarm.enabled) return false;

    // Calculate milliseconds until next alarm fire time.
    final now = DateTime.now();
    final nextFire = _nextAlarmDateTime(alarm, now);
    final delay = nextFire.difference(now);

    if (delay.isNegative || delay.inMilliseconds == 0) return false;

    final alarmId = alarm.id.hashCode;

    // Store int→string ID map for isolate bridge.
    await _saveAlarmIdMapping(alarmId, alarm.id);

    try {
      await AndroidAlarmManager.oneShot(
        delay,
        alarmId,
        _alarmCallback,
        alarmClock: true,
        rescheduleOnReboot: true,
        exact: true,
        wakeup: true,
      );
    } catch (e) {
      return false;
    }

    // Persist alarm data.
    await _saveAlarm(alarm);
    return true;
  }

  /// Schedule a repeating alarm for specific days of week.
  Future<bool> scheduleRepeatingAlarm(WakeAlarm alarm) async {
    if (!alarm.enabled || alarm.repeatDays.isEmpty) return false;

    final alarmId = alarm.id.hashCode;

    try {
      // Schedule for each repeat day individually.
      for (final day in alarm.repeatDays) {
        // DateTime.monday = 1 … DateTime.sunday = 7
        final dayAlarmId = alarmId ^ day.hashCode;
        // Store int→string ID map for isolate bridge.
        await _saveAlarmIdMapping(dayAlarmId, alarm.id);
        await AndroidAlarmManager.periodic(
          const Duration(days: 7),
          dayAlarmId,
          _alarmCallback,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
        );
      }
    } catch (e) {
      return false;
    }

    await _saveAlarm(alarm);
    return true;
  }

  /// Cancel a scheduled alarm.
  Future<bool> cancelAlarm(String alarmId) async {
    final id = alarmId.hashCode;
    try {
      await AndroidAlarmManager.cancel(id);
    } catch (_) {}

    // Also cancel repeat-day alarms if any.
    final alarm = await _loadAlarm(alarmId);
    if (alarm != null) {
      for (final day in alarm.repeatDays) {
        final dayId = id ^ day.hashCode;
        try {
          await AndroidAlarmManager.cancel(dayId);
        } catch (_) {}
      }
    }

    // Remove from isolate bridge map.
    await _removeAlarmIdMapping(id);

    await _removeAlarm(alarmId);
    return true;
  }

  /// Snooze: schedule the alarm again after snooze duration.
  Future<bool> snoozeAlarm(WakeAlarm alarm, int snoozeMinutes) async {
    final alarmId = Random().nextInt(0x7FFFFFFF);
    final delay = Duration(minutes: snoozeMinutes);

    // Store int→string ID map for isolate bridge.
    await _saveAlarmIdMapping(alarmId, alarm.id);

    try {
      await AndroidAlarmManager.oneShot(
        delay,
        alarmId,
        _alarmCallback,
        exact: true,
        wakeup: true,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Load all persisted alarms.
  Future<List<WakeAlarm>> loadAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_alarmsKey);
    if (raw == null) return [];

    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => WakeAlarm.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Private helpers ──────────────────────────────────────────

  /// Isolate bridge callback: writes pending_alarm_id to SharedPreferences
  /// so the main isolate can pick it up on app resume.
  static void _alarmCallback(int alarmId) {
    // This runs in a separate isolate — no Flutter UI possible.
    // Write the string alarm ID to SharedPreferences so the
    // main isolate's didChangeAppLifecycleState can read it.
    SharedPreferences.getInstance().then((prefs) {
      final rawMap = prefs.getString(_alarmIdMapKey);
      if (rawMap != null) {
        try {
          final map = jsonDecode(rawMap) as Map<String, dynamic>;
          final stringId = map[alarmId.toString()] as String?;
          if (stringId != null) {
            prefs.setString(_pendingAlarmIdKey, stringId);
          }
        } catch (_) {}
      }
    });
  }

  /// Save an int→string mapping for isolate bridge.
  Future<void> _saveAlarmIdMapping(int intId, String stringId) async {
    final prefs = await SharedPreferences.getInstance();
    final rawMap = prefs.getString(_alarmIdMapKey);
    final map = rawMap != null
        ? (jsonDecode(rawMap) as Map<String, dynamic>)
        : <String, dynamic>{};
    map[intId.toString()] = stringId;
    await prefs.setString(_alarmIdMapKey, jsonEncode(map));
  }

  /// Remove an int→string mapping from the isolate bridge map.
  Future<void> _removeAlarmIdMapping(int intId) async {
    final prefs = await SharedPreferences.getInstance();
    final rawMap = prefs.getString(_alarmIdMapKey);
    if (rawMap == null) return;
    try {
      final map = jsonDecode(rawMap) as Map<String, dynamic>;
      map.remove(intId.toString());
      await prefs.setString(_alarmIdMapKey, jsonEncode(map));
    } catch (_) {}
  }

  DateTime _nextAlarmDateTime(WakeAlarm alarm, DateTime now) {
    final target = DateTime(
      now.year,
      now.month,
      now.day,
      alarm.time.hour,
      alarm.time.minute,
    );

    if (alarm.isRepeating) {
      // Find next matching day.
      var candidate = target;
      for (int i = 0; i < 8; i++) {
        if (alarm.repeatDays.contains(candidate.weekday) &&
            candidate.isAfter(now)) {
          return candidate;
        }
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }

    // One-shot: if today's time already passed, schedule for tomorrow.
    if (target.isAfter(now)) return target;
    return target.add(const Duration(days: 1));
  }

  Future<void> _saveAlarm(WakeAlarm alarm) async {
    final alarms = await loadAlarms();
    final idx = alarms.indexWhere((a) => a.id == alarm.id);
    if (idx >= 0) {
      alarms[idx] = alarm;
    } else {
      alarms.add(alarm);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _alarmsKey, jsonEncode(alarms.map((a) => a.toJson()).toList()));
  }

  Future<void> _removeAlarm(String alarmId) async {
    final alarms = await loadAlarms();
    alarms.removeWhere((a) => a.id == alarmId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _alarmsKey, jsonEncode(alarms.map((a) => a.toJson()).toList()));
  }

  Future<WakeAlarm?> _loadAlarm(String alarmId) async {
    final alarms = await loadAlarms();
    try {
      return alarms.firstWhere((a) => a.id == alarmId);
    } catch (_) {
      return null;
    }
  }
}
