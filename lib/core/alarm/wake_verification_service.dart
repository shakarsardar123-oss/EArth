import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/alarm/wake_alarm.dart';
import '../../domain/entities/alarm/wake_verification_config.dart';
import '../../domain/entities/alarm/wake_verification_state.dart';
import '../../services/voice/voice_service.dart';
import '../../core/voice/voice_service_provider.dart';
import 'alarm_audio_service.dart';
import 'alarm_scheduler_service.dart';
import 'wake_verification_state_machine.dart';
import '../../services/camera/wake_camera_service.dart';
import '../../services/notifications/alarm_notification_service.dart';

/// Provider for WakeVerificationService.
final wakeVerificationProvider = Provider<WakeVerificationService>((ref) {
  return WakeVerificationService(
    scheduler: ref.read(alarmSchedulerProvider),
    audio: ref.read(alarmAudioProvider),
    camera: ref.read(wakeCameraProvider),
    notification: ref.read(alarmNotificationProvider),
    voice: ref.read(voiceServiceImplProvider),
  );
});

/// Orchestrator that ties together alarm scheduling, audio, camera,
/// notifications, and voice to perform wake verification.
class WakeVerificationService {
  final AlarmSchedulerService _scheduler;
  final AlarmAudioService _audio;
  final WakeCameraService _camera;
  final AlarmNotificationService _notification;
  final VoiceService _voice;

  final WakeVerificationStateMachine _stateMachine =
      WakeVerificationStateMachine();

  StreamSubscription<FaceDetectionResult>? _faceSub;
  Timer? _verificationTimer;
  // Double snooze bug fix: _snoozeTimer removed — only scheduler.snoozeAlarm()
  // is used to handle snooze via AndroidAlarmManager.oneShot.
  int _snoozeCount = 0;

  /// Current verification state.
  WakeVerificationState get state => _stateMachine.state;

  /// Stream of state changes.
  final _stateController =
      StreamController<WakeVerificationState>.broadcast();
  Stream<WakeVerificationState> get stateStream => _stateController.stream;

  WakeVerificationService({
    required AlarmSchedulerService scheduler,
    required AlarmAudioService audio,
    required WakeCameraService camera,
    required AlarmNotificationService notification,
    required VoiceService voice,
  })  : _scheduler = scheduler,
        _audio = audio,
        _camera = camera,
        _notification = notification,
        _voice = voice;

  /// Start the alarm ringing and verification flow.
  Future<void> triggerAlarm(WakeAlarm alarm) async {
    // Transition: idle → scheduled → ringing.
    if (!_stateMachine.transition(WakeVerificationState.scheduled)) return;
    _emit();

    if (!_stateMachine.transition(WakeVerificationState.ringing)) return;
    _emit();

    // Show full-screen notification.
    await _notification.showFullScreenAlarm(
      id: alarm.id.hashCode,
      title: alarm.label.isNotEmpty ? alarm.label : 'ئاگاداری',
      body: 'کاتەکەت هات! ${alarm.time.formatted}',
      wakeAlarmId: alarm.id,
    );

    // Start alarm sound + vibration.
    await _audio.startAlarm(
      targetVolume: alarm.verificationConfig.alarmVolume,
      vibrationEnabled: alarm.verificationConfig.vibrationEnabled,
    );

    // Voice guidance if enabled.
    if (alarm.verificationConfig.voiceGuidanceEnabled) {
      await _voice.speak('کاتەکەت هات! بۆ وەستاندنەوە، دەسگەیەک بکە.');
    }

    // Start verification after a brief ring period.
    _startVerification(alarm);
  }

  /// Begin verification checks based on alarm config.
  void _startVerification(WakeAlarm alarm) async {
    final config = alarm.verificationConfig;

    if (config.mode == WakeVerificationMode.none) {
      // Simple alarm — user just stops it.
      return;
    }

    // Start verification timeout timer.
    _verificationTimer?.cancel();
    _verificationTimer = Timer(
      Duration(seconds: config.verificationTimeoutSeconds),
      () => _onTimeout(alarm),
    );

    if (config.requireFaceDetectionFromMode ||
        config.requireFaceDetection) {
      // Transition: ringing → checking.
      if (_stateMachine.transition(WakeVerificationState.checking)) {
        _emit();
      }

      // Start camera face detection.
      await _camera.startFaceDetection();

      _faceSub = _camera.results.listen((result) {
        if (result.faceDetected && result.confidence > 0.7) {
          _onFaceDetected(alarm);
        }
      });
    } else if (config.requireVoiceConfirmationFromMode ||
        config.requireVoiceConfirmation) {
      // Skip face, go straight to voice.
      if (_stateMachine
          .transition(WakeVerificationState.awaitingVoiceConfirmation)) {
        _emit();
      }
      _startVoiceConfirmation(alarm);
    }
  }

  /// Face detected — transition and optionally start voice.
  void _onFaceDetected(WakeAlarm alarm) {
    if (_stateMachine.transition(WakeVerificationState.faceDetected)) {
      _emit();
    }

    if (alarm.verificationConfig.requireVoiceConfirmationFromMode ||
        alarm.verificationConfig.requireVoiceConfirmation) {
      // Need voice confirmation too.
      if (_stateMachine.transition(
          WakeVerificationState.awaitingVoiceConfirmation,
      )) {
        _emit();
      }
      _startVoiceConfirmation(alarm);
    } else {
      // Face-only verification is complete.
      _onVerified(alarm);
    }
  }

  /// Start listening for voice confirmation.
  void _startVoiceConfirmation(WakeAlarm alarm) {
    final phrase = alarm.verificationConfig.voicePhrase;

    if (alarm.verificationConfig.voiceGuidanceEnabled) {
      _voice.speak('بە دواپێشەوە بڵێ: $phrase');
    }

    _voice.startListening(
      onRecognized: (text) {
        // Check if the spoken text contains the required phrase.
        if (text.contains(phrase) || text.contains(phrase.toLowerCase())) {
          _onVerified(alarm);
        }
      },
      locale: 'ku',
    );
  }

  /// Verification succeeded.
  void _onVerified(WakeAlarm alarm) async {
    _cleanup();

    if (_stateMachine.transition(WakeVerificationState.verified)) {
      _emit();
    }

    // Stop alarm audio.
    await _audio.stopAlarm();

    // Voice confirmation.
    if (alarm.verificationConfig.voiceGuidanceEnabled) {
      await _voice.speak('ئامادەیت! بە سەرکەوتوویی تۆمارکرا.');
    }

    // Cancel notification.
    await _notification.cancelAlarmNotification(alarm.id.hashCode);

    // Transition to stopped then idle.
    if (_stateMachine.transition(WakeVerificationState.stopped)) {
      _emit();
    }
    _stateMachine.reset();
    _emit();
  }

  /// User snoozed the alarm.
  /// Double snooze bug fix: only scheduler.snoozeAlarm() is used.
  /// No Dart Timer, no ringing transition after snooze.
  Future<void> snooze(WakeAlarm alarm) async {
    _cleanup();

    if (_stateMachine.transition(WakeVerificationState.snoozed)) {
      _emit();
    }

    _snoozeCount++;
    if (_snoozeCount >= alarm.verificationConfig.maxSnoozeCount) {
      // Max snoozes reached, auto-stop.
      await _stopAlarm(alarm);
      return;
    }

    await _audio.stopAlarm();

    // Schedule snooze alarm via AndroidAlarmManager.oneShot only.
    await _scheduler.snoozeAlarm(
        alarm,
        alarm.verificationConfig.snoozeDurationMinutes,
      );

    if (alarm.verificationConfig.voiceGuidanceEnabled) {
      await _voice.speak(
          'خەوتنەوە بۆ ${alarm.verificationConfig.snoozeDurationMinutes} خولەک.',
        );
    }

    // Stay in snoozed state. No ringing transition.
    // No Dart _snoozeTimer — alarm re-triggers via Android alarm manager.
  }

  /// Stop/dismiss the alarm without verification (simple mode).
  Future<void> stopAlarm(WakeAlarm alarm) async {
    await _stopAlarm(alarm);
  }

  Future<void> _stopAlarm(WakeAlarm alarm) async {
    _cleanup();

    if (_stateMachine.transition(WakeVerificationState.stopped)) {
      _emit();
    }

    await _audio.stopAlarm();
    await _notification.cancelAlarmNotification(alarm.id.hashCode);
    await _camera.stopFaceDetection();

    // Cancel scheduled alarm if one-shot.
    if (!alarm.isRepeating) {
      await _scheduler.cancelAlarm(alarm.id);
    }

    _stateMachine.reset();
    _emit();
  }

  /// Verification timeout.
  void _onTimeout(WakeAlarm alarm) async {
    _cleanup();

    if (_stateMachine.transition(WakeVerificationState.timeout)) {
      _emit();
    }

    await _audio.stopAlarm();

    if (alarm.verificationConfig.voiceGuidanceEnabled) {
      await _voice.speak('کات تەواو بوو. ئاگاداریەکە ڕادەستکرا.');
    }

    if (_stateMachine.transition(WakeVerificationState.stopped)) {
      _emit();
    }
    _stateMachine.reset();
    _emit();
  }

  /// Clean up all resources (timers, subscriptions, etc).
  void _cleanup() {
    _faceSub?.cancel();
    _faceSub = null;
    _verificationTimer?.cancel();
    _verificationTimer = null;
    // Double snooze fix: _snoozeTimer removed — no longer exists.
    _camera.stopFaceDetection();
  }

  /// Emit state change.
  void _emit() {
    if (!_stateController.isClosed) {
      _stateController.add(_stateMachine.state);
    }
  }

  /// Dispose all resources.
  void dispose() {
    _cleanup();
    _stateController.close();
    // Tight coupling fix: VoiceService abstract has no dispose().
    // Conditional cast — only VoiceServiceImpl has dispose().
    try {
      (_voice as dynamic).dispose();
    } catch (_) {
      // VoiceService abstract does not expose dispose — safe to ignore.
    }
  }
}
