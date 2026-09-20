/// output_level_monitor.dart
/// AURA Assistant – Final Voice Phase: REAL AURA output audio level.
///
/// Provides a genuine acoustic output level (RMS, normalised 0..1) for AURA's
/// OWN voice while it is speaking, so the waveform reacts to the actual sound
/// coming out of the speaker rather than to a word-boundary envelope.
///
/// WHY A NATIVE PATH: flutter_tts exposes NO PCM stream and NO amplitude/RMS
/// callback (only word-boundary progress). The only legitimate way to obtain
/// AURA's real output amplitude on Android is the platform
/// `android.media.audiofx.Visualizer`, attached to the output mix
/// (session 0). The native side computes RMS from the Visualizer waveform and
/// streams it here via an EventChannel. This captures the device's own audio
/// output mix (which is what AURA is playing) — it does NOT record another
/// app's private audio and does NOT use AudioPlaybackCapture on other apps.
///
/// Behind an interface so the engine can be swapped and so a stub can be used
/// on platforms/tests where the Visualizer is unavailable (fail-closed to a
/// silent 0.0 rather than a fake animation).
library;

import 'dart:async';

import 'package:flutter/services.dart';

import 'audio_signal_math.dart';

/// Capability/health of the output-level monitor.
enum OutputLevelStatus { unknown, active, unavailable }

/// Interface for a real AURA output-audio-level source (0..1).
abstract class OutputLevelMonitor {
  /// Normalised (0..1) real output level while AURA is speaking. Emits 0.0
  /// when idle. Never emits random/fabricated values.
  Stream<double> get levelStream;

  /// Current capability status.
  OutputLevelStatus get status;

  /// Begin monitoring the output mix. Safe to call repeatedly.
  Future<OutputLevelStatus> start();

  /// Stop monitoring and release native resources.
  Future<void> stop();
}

/// EventChannel-backed monitor reading a REAL Visualizer RMS from Android.
class NativeOutputLevelMonitor implements OutputLevelMonitor {
  NativeOutputLevelMonitor({
    EventChannel? eventChannel,
    MethodChannel? controlChannel,
  })  : _events = eventChannel ??
            const EventChannel('com.aura.aura_assistant/output_level.events'),
        _control = controlChannel ??
            const MethodChannel('com.aura.aura_assistant/output_level');

  final EventChannel _events;
  final MethodChannel _control;

  final _controller = StreamController<double>.broadcast();
  final _smoother = LevelSmoother(attack: 0.6, release: 0.18);
  StreamSubscription<dynamic>? _sub;
  OutputLevelStatus _status = OutputLevelStatus.unknown;

  @override
  Stream<double> get levelStream => _controller.stream;

  @override
  OutputLevelStatus get status => _status;

  @override
  Future<OutputLevelStatus> start() async {
    try {
      final ok = await _control.invokeMethod<bool>('start') ?? false;
      if (!ok) {
        _status = OutputLevelStatus.unavailable;
        return _status;
      }
      _sub ??= _events.receiveBroadcastStream().listen(
        (event) {
          // Native sends a linear 0..1 RMS already normalised on its side.
          final raw = (event is num) ? event.toDouble() : 0.0;
          final smoothed = _smoother.add(raw.clamp(0.0, 1.0));
          if (!_controller.isClosed) _controller.add(smoothed);
        },
        onError: (_) {
          _status = OutputLevelStatus.unavailable;
        },
      );
      _status = OutputLevelStatus.active;
    } on PlatformException {
      _status = OutputLevelStatus.unavailable;
    } on MissingPluginException {
      _status = OutputLevelStatus.unavailable;
    }
    return _status;
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _smoother.reset();
    try {
      await _control.invokeMethod('stop');
    } catch (_) {
      // Non-fatal.
    }
    if (!_controller.isClosed) _controller.add(0.0);
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}

/// Safe fallback: always reports unavailable and never emits fake motion.
/// Consumers should fall back to the existing TTS word-activity envelope.
class StubOutputLevelMonitor implements OutputLevelMonitor {
  final _controller = StreamController<double>.broadcast();

  @override
  Stream<double> get levelStream => _controller.stream;

  @override
  OutputLevelStatus get status => OutputLevelStatus.unavailable;

  @override
  Future<OutputLevelStatus> start() async => OutputLevelStatus.unavailable;

  @override
  Future<void> stop() async {}
}
