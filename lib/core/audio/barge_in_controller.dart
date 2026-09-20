/// barge_in_controller.dart
/// AURA Assistant – Final Voice Phase: automatic acoustic barge-in.
///
/// Bridges the [EchoSafeMicMonitor] (post-AEC mic frames) and the Dart
/// [VoiceActivityDetector] to trigger barge-in while AURA is SPEAKING, WITHOUT
/// opening a second microphone and WITHOUT feeding AURA's own voice back into
/// the recognizer as user speech (that is what the AEC + VAD hysteresis are
/// for).
///
/// Flow while SPEAKING:
///   mic frame (post-AEC) → VAD.addFrame → confirmed speechStart → onBargeIn()
///
/// The controller only listens during SPEAKING (armed by the coordinator) and
/// only fires on a CONFIRMED speech onset (VAD startFrames), never on a single
/// amplitude spike. The existing manual/explicit barge-in remains available as
/// a fallback and is unaffected.
library;

import 'dart:async';

import 'echo_safe_mic_monitor.dart';
import 'voice_activity_detector.dart';

/// Drives automatic barge-in from real post-AEC speech detection.
class BargeInController {
  BargeInController({
    required EchoSafeMicMonitor micMonitor,
    VoiceActivityDetector? vad,
  })  : _mic = micMonitor,
        _vad = vad ?? VoiceActivityDetector();

  final EchoSafeMicMonitor _mic;
  final VoiceActivityDetector _vad;

  StreamSubscription<MicFrame>? _sub;
  bool _armed = false;

  /// Called when a genuine user speech onset is detected during SPEAKING.
  void Function()? onBargeIn;

  bool get isArmed => _armed;

  /// AEC status surfaced for UI/telemetry.
  AecStatus get aecStatus => _mic.aecStatus;

  /// Arm barge-in detection: opens the echo-safe mic (if not already) and
  /// watches for a confirmed speech onset. Call when entering SPEAKING.
  Future<void> arm() async {
    if (_armed) return;
    _armed = true;
    _vad.reset();
    await _mic.start();
    _sub ??= _mic.frameStream.listen((frame) {
      if (!_armed) return;
      final t = _vad.addFrame(frame.level, zcr: frame.zcr);
      if (t == VadTransition.speechStart) {
        onBargeIn?.call();
      }
    });
  }

  /// Disarm and release the mic. Call when leaving SPEAKING (or session end).
  Future<void> disarm() async {
    if (!_armed) return;
    _armed = false;
    await _sub?.cancel();
    _sub = null;
    await _mic.stop();
    _vad.reset();
  }

  Future<void> dispose() async {
    await disarm();
  }
}
