import 'wake_verification_config.dart';

/// Represents a single wake verification alarm.
class WakeAlarm {
  WakeAlarm({
    required this.id,
    required this.time,
    this.label = '',
    this.enabled = true,
    this.repeatDays = const [],
    this.verificationConfig = const WakeVerificationConfig(),
    this.snoozeDurationMinutes = 5,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? _defaultCreatedAt;

  static final _defaultCreatedAt = DateTime(2024, 1, 1);

  final String id;
  final TimeOfDayData time;
  final String label;
  final bool enabled;
  final List<int> repeatDays;
  final WakeVerificationConfig verificationConfig;
  final int snoozeDurationMinutes;
  final DateTime createdAt;

  bool get isRepeating => repeatDays.isNotEmpty;

  bool get requiresVerification =>
      verificationConfig.mode != WakeVerificationMode.none;

  WakeAlarm copyWith({
    String? id,
    TimeOfDayData? time,
    String? label,
    bool? enabled,
    List<int>? repeatDays,
    WakeVerificationConfig? verificationConfig,
    int? snoozeDurationMinutes,
    DateTime? createdAt,
  }) {
    return WakeAlarm(
      id: id ?? this.id,
      time: time ?? this.time,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      repeatDays: repeatDays ?? this.repeatDays,
      verificationConfig: verificationConfig ?? this.verificationConfig,
      snoozeDurationMinutes:
          snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toJson(),
        'label': label,
        'enabled': enabled,
        'repeatDays': repeatDays,
        'verificationConfig': verificationConfig.toJson(),
        'snoozeDurationMinutes': snoozeDurationMinutes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory WakeAlarm.fromJson(Map<String, dynamic> json) => WakeAlarm(
        id: json['id'] as String,
        time: TimeOfDayData.fromJson(json['time'] as Map<String, dynamic>),
        label: json['label'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        repeatDays: (json['repeatDays'] as List?)?.cast<int>() ?? [],
        verificationConfig: WakeVerificationConfig.fromJson(
          json['verificationConfig'] as Map<String, dynamic>? ?? {},
        ),
        snoozeDurationMinutes: json['snoozeDurationMinutes'] as int? ?? 5,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime(2024, 1, 1),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WakeAlarm && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'WakeAlarm(id: $id, time: $time, label: $label, enabled: $enabled)';
}

/// Simple hour:minute data class (avoids Flutter material dependency in domain).
class TimeOfDayData {
  const TimeOfDayData({required this.hour, required this.minute});

  final int hour;
  final int minute;

  Map<String, dynamic> toJson() => {'hour': hour, 'minute': minute};

  factory TimeOfDayData.fromJson(Map<String, dynamic> json) =>
      TimeOfDayData(
        hour: json['hour'] as int,
        minute: json['minute'] as int,
      );

  String get formatted =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeOfDayData && hour == other.hour && minute == other.minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => 'TimeOfDayData($formatted)';
}
