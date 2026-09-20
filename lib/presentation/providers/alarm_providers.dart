import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/alarm/wake_alarm.dart';
import '../../domain/entities/alarm/wake_verification_config.dart';
import '../../domain/entities/alarm/wake_verification_state.dart';
import '../../core/alarm/alarm_scheduler_service.dart';
import '../../core/alarm/wake_verification_service.dart';

// ─── Existing service providers (re-exported from their modules) ───

export '../../core/alarm/alarm_scheduler_service.dart' show alarmSchedulerProvider;
export '../../core/alarm/alarm_audio_service.dart' show alarmAudioProvider;

// WakeCameraService provider re-exported from its module.
export '../../services/camera/wake_camera_service.dart' show wakeCameraProvider;

// AlarmNotificationService provider re-exported from its module.
export '../../services/notifications/alarm_notification_service.dart' show alarmNotificationProvider;

// ─── Alarm state notifier ───

/// Notifier managing the list of alarms and current verification state.
class AlarmListNotifier extends StateNotifier<List<WakeAlarm>> {
  AlarmListNotifier(this._scheduler) : super([]);

  final AlarmSchedulerService _scheduler;
  StreamSubscription<List<WakeAlarm>>? _sub;

  /// Load persisted alarms on init.
  Future<void> init() async {
    final alarms = await _scheduler.loadAlarms();
    state = alarms;
  }

  /// Add a new alarm.
  Future<void> addAlarm(WakeAlarm alarm) async {
    await _scheduler.scheduleAlarm(alarm);
    state = [...state, alarm];
  }

  /// Update an existing alarm.
  Future<void> updateAlarm(WakeAlarm alarm) async {
    await _scheduler.cancelAlarm(alarm.id);
    if (alarm.enabled) {
      await _scheduler.scheduleAlarm(alarm);
    }
    state = [
      for (final a in state)
        if (a.id == alarm.id) alarm else a,
    ];
  }

  /// Delete an alarm.
  Future<void> deleteAlarm(String alarmId) async {
    await _scheduler.cancelAlarm(alarmId);
    state = state.where((a) => a.id != alarmId).toList();
  }

  /// Toggle alarm enabled/disabled.
  Future<void> toggleAlarm(String alarmId) async {
    final alarm = state.firstWhere((a) => a.id == alarmId);
    final toggled = alarm.copyWith(enabled: !alarm.enabled);
    await updateAlarm(toggled);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Provider for the alarm list notifier.
final alarmListProvider =
    StateNotifierProvider<AlarmListNotifier, List<WakeAlarm>>((ref) {
  final scheduler = ref.read(alarmSchedulerProvider);
  final notifier = AlarmListNotifier(scheduler);
  // Auto-init on first watch.
  notifier.init();
  return notifier;
});

// ─── Current verification state ───

/// Notifier tracking current wake verification state.
class WakeVerificationNotifier extends StateNotifier<WakeVerificationState> {
  WakeVerificationNotifier(this._service) : super(WakeVerificationState.idle) {
    _sub = _service.stateStream.listen((s) {
      state = s;
    });
  }

  final WakeVerificationService _service;
  StreamSubscription<WakeVerificationState>? _sub;

  /// Trigger alarm.
  Future<void> triggerAlarm(WakeAlarm alarm) async {
    await _service.triggerAlarm(alarm);
  }

  /// Snooze alarm.
  Future<void> snooze(WakeAlarm alarm) async {
    await _service.snooze(alarm);
  }

  /// Stop/dismiss alarm.
  Future<void> stopAlarm(WakeAlarm alarm) async {
    await _service.stopAlarm(alarm);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Provider for the wake verification notifier.
final wakeVerificationStateProvider =
    StateNotifierProvider<WakeVerificationNotifier, WakeVerificationState>(
        (ref) {
  final service = ref.read(wakeVerificationProvider);
  return WakeVerificationNotifier(service);
});

// ─── Alarm config defaults ───

/// Default verification config provider.
final defaultVerificationConfigProvider = Provider<WakeVerificationConfig>((ref) {
  return const WakeVerificationConfig();
});

/// Currently selected alarm for editing.
final selectedAlarmProvider = StateProvider<WakeAlarm?>((ref) => null);

/// Currently editing verification config.
final editingConfigProvider =
    StateProvider<WakeVerificationConfig>((ref) => const WakeVerificationConfig());

/// Currently editing repeat days (list of day numbers 1=Mon..7=Sun).
final editingRepeatDaysProvider = StateProvider<List<int>>((ref) => []);
