import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Provider for AlarmNotificationService.
final alarmNotificationProvider = Provider<AlarmNotificationService>((ref) {
  return AlarmNotificationService();
});

/// Full-screen notification service for wake alarms.
///
/// Uses flutter_local_notifications to show a high-priority
/// full-screen intent notification that wakes the device and
/// launches AlarmWakeActivity.
class AlarmNotificationService {
  static const _channelId = 'wake_alarm_channel';
  static const _channelName = 'Wake Alarm';
  static const _channelDescription = 'Full-screen alarm notifications';

  /// Callback invoked when user taps an alarm notification.
  /// Wired from main.dart to navigate to WakeAlarmScreen.
  static void Function(String)? onActionCallback;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize the notification plugin.
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request exact alarm permission on Android 12+.
    if (Platform.isAndroid) {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestExactAlarmsPermission();
    }

    _initialized = true;
  }

  /// Show a full-screen alarm notification.
  /// This will wake the screen and show over the lock screen.
  Future<void> showFullScreenAlarm({
    required int id,
    required String title,
    required String body,
    String? wakeAlarmId,
  }) async {
    if (!_initialized) await init();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      autoCancel: false,
      ongoing: true,
      playSound: false, // We handle sound via AlarmAudioService.
      enableVibration: false, // We handle vibration via AlarmAudioService.
      visibility: NotificationVisibility.public,
      showWhen: true,
      usesChronometer: false,
      // Additional intent data for AlarmWakeActivity.
      additionalFlags: Int32List.fromList([0x10000000]), // FLAG_ACTIVITY_NEW_TASK
    );

    // Payload carries the wake alarm ID for the activity to process.
    final payload = wakeAlarmId ?? '';

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
      ),
    );

    await _plugin.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Cancel the alarm notification.
  Future<void> cancelAlarmNotification(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel all notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Handle notification tap — launches the alarm screen.
  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      // Invoke the static callback if registered.
      onActionCallback?.call(payload);
    }
  }
}
