import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the concrete NotificationService implementation.
final notificationServiceProvider = Provider<NotificationServiceImpl>((ref) {
  return NotificationServiceImpl();
});

/// Concrete implementation of local notification handling for AURA.
///
/// Uses flutter_local_notifications to:
/// - initialize platform-specific notification channels
/// - request Android 13+ notification permission
/// - show / cancel general-purpose notifications
/// - schedule notifications where supported
/// - create distinct Android notification channels
///
/// This is NOT the alarm-specific service (see AlarmNotificationService
/// for full-screen wake alarms). This handles general notifications
/// such as AI response arrivals, reminders, and status updates.
class NotificationServiceImpl {
  // ── Channel IDs ─────────────────────────────────────────────
  static const _generalChannelId = 'aura_general';
  static const _generalChannelName = 'AURA General';
  static const _generalChannelDesc = 'General AURA notifications';

  static const _reminderChannelId = 'aura_reminders';
  static const _reminderChannelName = 'AURA Reminders';
  static const _reminderChannelDesc = 'Scheduled reminders from AURA';

  static const _statusChannelId = 'aura_status';
  static const _statusChannelName = 'AURA Status';
  static const _statusChannelDesc = 'Background status updates';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _nextId = 1000; // start above alarm IDs to avoid collision

  // ── Initialization ──────────────────────────────────────────

  /// Initialize the notification plugin and create channels.
  ///
  /// Must be called once before any notification operations.
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone database for scheduled notifications
    tz.initializeTimeZones();

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

    _initialized = true;
  }

  // ── Permission ──────────────────────────────────────────────

  /// Requests notification permission (Android 13+, iOS).
  /// Returns true if granted, false otherwise.
  Future<bool> requestPermissions() async {
    if (!_initialized) await init();

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? false;
    }

    if (Platform.isIOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return false;
  }

  // ── Show notification ───────────────────────────────────────

  /// Shows a local notification with [title] and [body].
  ///
  /// [channel] determines which Android notification channel to use.
  /// [id] defaults to an auto-incrementing counter.
  /// Returns the notification ID used.
  Future<int> showNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
    NotificationChannel channel = NotificationChannel.general,
  }) async {
    if (!_initialized) await init();

    final notifId = id ?? _nextId++;

    final androidDetails = AndroidNotificationDetails(
      _channelIdFor(channel),
      _channelNameFor(channel),
      channelDescription: _channelDescFor(channel),
      importance: _importanceFor(channel),
      priority: _priorityFor(channel),
      category: AndroidNotificationCategory.message,
      autoCancel: true,
      visibility: NotificationVisibility.public,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      notifId,
      title,
      body,
      details,
      payload: payload,
    );

    return notifId;
  }

  // ── Scheduled notification ──────────────────────────────────

  /// Schedules a notification to appear at [scheduledTime].
  ///
  /// Uses Android's alarm-based scheduling.
  /// Returns the notification ID used.
  Future<int> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    int? id,
    NotificationChannel channel = NotificationChannel.reminder,
  }) async {
    if (!_initialized) await init();

    final notifId = id ?? _nextId++;

    final androidDetails = AndroidNotificationDetails(
      _channelIdFor(channel),
      _channelNameFor(channel),
      channelDescription: _channelDescFor(channel),
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      autoCancel: true,
      visibility: NotificationVisibility.public,
      showWhen: true,
      when: scheduledTime.millisecondsSinceEpoch,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Convert DateTime to TZDateTime for zonedSchedule
    final tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);

    await _plugin.zonedSchedule(
      notifId,
      title,
      body,
      tzScheduled,
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );

    return notifId;
  }

  // ── Cancel ─────────────────────────────────────────────────

  /// Cancels a notification by [id].
  Future<void> cancelNotification(int id) async {
    if (!_initialized) await init();
    await _plugin.cancel(id);
  }

  /// Cancels all notifications.
  Future<void> cancelAllNotifications() async {
    if (!_initialized) await init();
    await _plugin.cancelAll();
  }

  // ── Notification tap handler ────────────────────────────────

  /// Callback invoked when user taps a notification.
  /// Override behavior by setting [onNotificationTap].
  static void Function(String? payload)? onNotificationTap;

  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    onNotificationTap?.call(payload);
  }

  // ── Helpers ─────────────────────────────────────────────────

  String _channelIdFor(NotificationChannel channel) {
    switch (channel) {
      case NotificationChannel.general:
        return _generalChannelId;
      case NotificationChannel.reminder:
        return _reminderChannelId;
      case NotificationChannel.status:
        return _statusChannelId;
    }
  }

  String _channelNameFor(NotificationChannel channel) {
    switch (channel) {
      case NotificationChannel.general:
        return _generalChannelName;
      case NotificationChannel.reminder:
        return _reminderChannelName;
      case NotificationChannel.status:
        return _statusChannelName;
    }
  }

  String _channelDescFor(NotificationChannel channel) {
    switch (channel) {
      case NotificationChannel.general:
        return _generalChannelDesc;
      case NotificationChannel.reminder:
        return _reminderChannelDesc;
      case NotificationChannel.status:
        return _statusChannelDesc;
    }
  }

  Importance _importanceFor(NotificationChannel channel) {
    switch (channel) {
      case NotificationChannel.general:
        return Importance.defaultImportance;
      case NotificationChannel.reminder:
        return Importance.high;
      case NotificationChannel.status:
        return Importance.low;
    }
  }

  Priority _priorityFor(NotificationChannel channel) {
    switch (channel) {
      case NotificationChannel.general:
        return Priority.defaultPriority;
      case NotificationChannel.reminder:
        return Priority.high;
      case NotificationChannel.status:
        return Priority.low;
    }
  }
}

/// Notification channel types for AURA.
enum NotificationChannel {
  /// General-purpose messages (AI responses, tips).
  general,

  /// Scheduled reminders.
  reminder,

  /// Background status updates.
  status,
}

/// Kept for backward compatibility — the abstract class that
/// NotificationServiceImpl replaces. Callers that reference
/// NotificationService can use NotificationServiceImpl directly.
abstract class NotificationService {
  /// Requests notification permissions (Android 13+).
  Future<bool> requestPermissions();

  /// Shows a local notification with [title] and [body].
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
  });

  /// Cancels a notification by [id].
  Future<void> cancelNotification(int id);

  /// Cancels all notifications.
  Future<void> cancelAllNotifications();
}
