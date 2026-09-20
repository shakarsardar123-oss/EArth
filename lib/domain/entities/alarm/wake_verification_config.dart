/// Configuration for how the alarm verifies the user is awake.
enum WakeVerificationMode {
  /// No verification — simple stop dismisses alarm.
  none,

  /// Voice confirmation required (say a specific phrase).
  voice,

  /// Camera face detection required.
  face,

  /// Both face detection AND voice confirmation required.
  combined,
}

/// Configuration for a single wake verification alarm.
class WakeVerificationConfig {
  const WakeVerificationConfig({
    this.mode = WakeVerificationMode.none,
    this.voicePhrase = 'ئامادەم',
    this.requireFaceDetection = false,
    this.requireVoiceConfirmation = false,
    this.snoozeDurationMinutes = 5,
    this.maxSnoozeCount = 3,
    this.verificationTimeoutSeconds = 60,
    this.alarmVolume = 0.8,
    this.vibrationEnabled = true,
    this.voiceGuidanceEnabled = true,
    this.cameraPrivacyMode = true,
  });

  /// Which verification mode is active.
  final WakeVerificationMode mode;

  /// The phrase the user must say for voice confirmation (Kurdish Sorani default).
  final String voicePhrase;

  /// Whether face detection is required (derived from mode).
  bool get requireFaceDetectionFromMode =>
      mode == WakeVerificationMode.face ||
      mode == WakeVerificationMode.combined;

  /// Whether voice confirmation is required (derived from mode).
  bool get requireVoiceConfirmationFromMode =>
      mode == WakeVerificationMode.voice ||
      mode == WakeVerificationMode.combined;

  /// Legacy bool flags for backward compatibility.
  final bool requireFaceDetection;
  final bool requireVoiceConfirmation;

  /// How long each snooze lasts.
  final int snoozeDurationMinutes;

  /// Maximum snooze count before alarm auto-stops.
  final int maxSnoozeCount;

  /// Seconds before verification times out.
  final int verificationTimeoutSeconds;

  /// Alarm volume (0.0–1.0).
  final double alarmVolume;

  /// Whether vibration is enabled.
  final bool vibrationEnabled;

  /// Whether AURA provides voice guidance during alarm.
  final bool voiceGuidanceEnabled;

  /// Privacy-first mode: camera frames are processed in-memory only,
  /// never saved to disk. Always true.
  final bool cameraPrivacyMode;

  /// Creates a copy with optional overrides.
  WakeVerificationConfig copyWith({
    WakeVerificationMode? mode,
    String? voicePhrase,
    bool? requireFaceDetection,
    bool? requireVoiceConfirmation,
    int? snoozeDurationMinutes,
    int? maxSnoozeCount,
    int? verificationTimeoutSeconds,
    double? alarmVolume,
    bool? vibrationEnabled,
    bool? voiceGuidanceEnabled,
    bool? cameraPrivacyMode,
  }) {
    return WakeVerificationConfig(
      mode: mode ?? this.mode,
      voicePhrase: voicePhrase ?? this.voicePhrase,
      requireFaceDetection: requireFaceDetection ?? this.requireFaceDetection,
      requireVoiceConfirmation:
          requireVoiceConfirmation ?? this.requireVoiceConfirmation,
      snoozeDurationMinutes:
          snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      maxSnoozeCount: maxSnoozeCount ?? this.maxSnoozeCount,
      verificationTimeoutSeconds:
          verificationTimeoutSeconds ?? this.verificationTimeoutSeconds,
      alarmVolume: alarmVolume ?? this.alarmVolume,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      voiceGuidanceEnabled: voiceGuidanceEnabled ?? this.voiceGuidanceEnabled,
      cameraPrivacyMode: cameraPrivacyMode ?? this.cameraPrivacyMode,
    );
  }

  /// Serialize to JSON map for persistence.
  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'voicePhrase': voicePhrase,
        'requireFaceDetection': requireFaceDetection,
        'requireVoiceConfirmation': requireVoiceConfirmation,
        'snoozeDurationMinutes': snoozeDurationMinutes,
        'maxSnoozeCount': maxSnoozeCount,
        'verificationTimeoutSeconds': verificationTimeoutSeconds,
        'alarmVolume': alarmVolume,
        'vibrationEnabled': vibrationEnabled,
        'voiceGuidanceEnabled': voiceGuidanceEnabled,
        'cameraPrivacyMode': cameraPrivacyMode,
      };

  /// Deserialize from JSON map.
  factory WakeVerificationConfig.fromJson(Map<String, dynamic> json) =>
      WakeVerificationConfig(
        mode: WakeVerificationMode.values.firstWhere(
          (e) => e.name == json['mode'],
          orElse: () => WakeVerificationMode.none,
        ),
        voicePhrase: json['voicePhrase'] as String? ?? 'ئامادەم',
        requireFaceDetection: json['requireFaceDetection'] as bool? ?? false,
        requireVoiceConfirmation:
            json['requireVoiceConfirmation'] as bool? ?? false,
        snoozeDurationMinutes:
            json['snoozeDurationMinutes'] as int? ?? 5,
        maxSnoozeCount: json['maxSnoozeCount'] as int? ?? 3,
        verificationTimeoutSeconds:
            json['verificationTimeoutSeconds'] as int? ?? 60,
        alarmVolume: (json['alarmVolume'] as num?)?.toDouble() ?? 0.8,
        vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
        voiceGuidanceEnabled: json['voiceGuidanceEnabled'] as bool? ?? true,
        cameraPrivacyMode: json['cameraPrivacyMode'] as bool? ?? true,
      );
}
