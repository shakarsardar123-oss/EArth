import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';


/// Provider for AlarmAudioService.
final alarmAudioProvider = Provider<AlarmAudioService>((ref) {
  return AlarmAudioService();
});

/// Manages alarm sound playback and vibration.
///
/// Uses audioplayers for alarm tone and vibration package for haptics.
/// Supports gradual volume increase and different alarm tones.
class AlarmAudioService {
  AudioPlayer? _player;
  bool _isPlaying = false;

  /// Current volume level (0.0 – 1.0).
  double _currentVolume = 0.0;

  bool get isPlaying => _isPlaying;

  /// Start alarm sound with optional vibration.
  /// Gradually increases volume from 0 to [targetVolume] over
  /// [rampDurationSeconds] seconds for a gentler wake-up.
  Future<void> startAlarm({
    double targetVolume = 0.8,
    bool vibrationEnabled = true,
    int rampDurationSeconds = 10,
    String toneAsset = 'assets/audio/alarm_tone.mp3',
  }) async {
    _player = AudioPlayer();
    _isPlaying = true;
    _currentVolume = 0.0;

    // Set initial volume to 0 and ramp up.
    await _player!.setVolume(0.0);
    await _player!.setReleaseMode(ReleaseMode.loop);
    await _player!.setSource(AssetSource(toneAsset.replaceFirst('assets/', '')));
    await _player!.resume();

    // Gradual volume ramp.
    _rampVolume(targetVolume, rampDurationSeconds);

    // Start vibration pattern if enabled and device supports it.
    if (vibrationEnabled) {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        _startVibrationPattern();
      }
    }
  }

  /// Stop alarm sound and vibration immediately.
  Future<void> stopAlarm() async {
    _isPlaying = false;
    await _player?.stop();
    await _player?.dispose();
    _player = null;
    _currentVolume = 0.0;

    try {
      Vibration.cancel();
    } catch (_) {
      // Vibration cancel may fail silently.
    }
  }

  /// Set volume immediately (no ramp).
  Future<void> setVolume(double volume) async {
    _currentVolume = volume.clamp(0.0, 1.0);
    await _player?.setVolume(_currentVolume);
  }

  /// Pause alarm sound (keeps player alive for resume).
  Future<void> pause() async {
    await _player?.pause();
    try {
      Vibration.cancel();
    } catch (_) {}
  }

  /// Resume alarm sound after pause.
  Future<void> resume() async {
    await _player?.resume();
  }

  // ── Private helpers ──────────────────────────────────────────

  /// Gradually increase volume from current to [targetVolume].
  void _rampVolume(double targetVolume, int durationSeconds) {
    if (durationSeconds <= 0) {
      setVolume(targetVolume);
      return;
    }

    final steps = durationSeconds * 2; // Update every 500ms.
    final volumeStep = targetVolume / steps;
    var step = 0;

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isPlaying) return;
      step++;
      _currentVolume = (volumeStep * step).clamp(0.0, targetVolume);
      _player?.setVolume(_currentVolume);
      if (step < steps) {
        _rampVolume(targetVolume, durationSeconds - 1);
      }
    });
  }

  /// Vibration pattern: 500ms on, 500ms off, repeat.
  void _startVibrationPattern() async {
    const pattern = [500, 500, 500, 500, 500, 500, 500, 500];
    try {
      Vibration.vibrate(pattern: pattern, repeat: 0);
    } catch (_) {
      // Pattern vibration not supported on all devices.
      try {
        Vibration.vibrate(duration: 2000);
      } catch (_) {}
    }
  }
}
