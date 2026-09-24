/// echo_safe_mic_monitor.dart
/// AURA Assistant – Final Voice Phase: echo-safe microphone + AEC + VAD.
///
/// Provides a SINGLE coordinated mic-input pipeline that can stay active while
/// AURA is speaking, so real barge-in is possible without opening a second
/// microphone. On Android the native side:
///
///   1. Opens ONE AudioRecord using MediaRecorder.AudioSource.VOICE_COMMUNICATION
///      (the platform routes this through hardware AEC/AGC/NS where present).
///   2. Additionally attaches android.media.audiofx.AcousticEchoCanceler and
///      NoiseSuppressor to that AudioRecord session when the device reports
///      them available — this is REAL AEC, not a volume trick.
///   3. Reports true AEC capability: AEC_UNAVAILABLE when the platform has no
///      AcousticEchoCanceler, AEC_SUPPORTED when it exists but is not enabled,
///      AEC_ACTIVE only when the effect object is actually enabled.
///   4. Computes per-frame RMS on the post-AEC signal and streams frame levels
///      here; the Dart VoiceActivityDetector confirms genuine speech onset
///      (not a single spike) to drive barge-in.
///
/// HONESTY: AEC quality is entirely device/hardware dependent. When neither
/// hardware nor software AEC is available, the monitor still runs but reports
/// AEC_UNAVAILABLE, and the coordinator keeps the safe fallback of stopping
/// STT before TTS. We never claim AEC_ACTIVE when the effect is not enabled.
library;

import 'dart:async';

import 'package:flutter/services.dart';

/// Real AEC capability status — mirrors the requirement's three states.
enum AecStatus { supported, active, unavailable }

/// A microphone frame event carrying the post-AEC normalised level and the
/// zero-crossing rate for the Dart VAD.
class MicFrame {
  const MicFrame({required this.level, required this.zcr});
  final double level; // 0..1 RMS (post-AEC)
  final double zcr; // 0..1 zero-crossing rate
}

/// Interface for the echo-safe mic monitor.
abstract class EchoSafeMicMonitor {
  /// Stream of post-AEC mic frames (level + zcr). Empty until [start].
  Stream<MicFrame> get frameStream;

  /// Current AEC capability.
  AecStatus get aecStatus;

  /// Whether the monitor is currently capturing.
  bool get isRunning;

  /// Start capture. Returns the resolved AEC status.
  Future<AecStatus> start();

  /// Stop capture and release the AudioRecord + effects.
  Future<void> stop();
}

/// EventChannel-backed monitor bridging the native AudioRecord+AEC pipeline.
class NativeEchoSafeMicMonitor implements EchoSafeMicMonitor {
  NativeEchoSafeMicMonitor({
    EventChannel? eventChannel,
    MethodChannel? controlChannel,
  })  : _events = eventChannel ??
            const EventChannel('com.texo.texo/mic_vad.events'),
        _control = controlChannel ??
            const MethodChannel('com.texo.texo/mic_vad');

  final EventChannel _events;
  final MethodChannel _control;

  final _controller = StreamController<MicFrame>.broadcast();
  StreamSubscription<dynamic>? _sub;
  AecStatus _aec = AecStatus.unavailable;
  bool _running = false;

  @override
  Stream<MicFrame> get frameStream => _controller.stream;

  @override
  AecStatus get aecStatus => _aec;

  @override
  bool get isRunning => _running;

  @override
  Future<AecStatus> start() async {
    if (_running) return _aec;
    try {
      final res = await _control.invokeMapMethod<String, dynamic>('start');
      final statusStr = (res?['aec'] as String?) ?? 'unavailable';
      _aec = _parse(statusStr);
      if ((res?['started'] as bool?) ?? false) {
        _running = true;
        _sub ??= _events.receiveBroadcastStream().listen(
          (event) {
            if (event is Map) {
              final level = (event['level'] as num?)?.toDouble() ?? 0.0;
              final zcr = (event['zcr'] as num?)?.toDouble() ?? 0.5;
              if (!_controller.isClosed) {
                _controller.add(MicFrame(
                  level: level.clamp(0.0, 1.0),
                  zcr: zcr.clamp(0.0, 1.0),
                ));
              }
            }
          },
          onError: (_) {},
        );
      }
    } on PlatformException {
      _aec = AecStatus.unavailable;
    } on MissingPluginException {
      _aec = AecStatus.unavailable;
    }
    return _aec;
  }

  @override
  Future<void> stop() async {
    _running = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _control.invokeMethod('stop');
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  static AecStatus _parse(String s) {
    switch (s) {
      case 'active':
        return AecStatus.active;
      case 'supported':
        return AecStatus.supported;
      default:
        return AecStatus.unavailable;
    }
  }
}

/// Safe fallback that never opens a mic and reports AEC unavailable.
class StubEchoSafeMicMonitor implements EchoSafeMicMonitor {
  final _controller = StreamController<MicFrame>.broadcast();

  @override
  Stream<MicFrame> get frameStream => _controller.stream;

  @override
  AecStatus get aecStatus => AecStatus.unavailable;

  @override
  bool get isRunning => false;

  @override
  Future<AecStatus> start() async => AecStatus.unavailable;

  @override
  Future<void> stop() async {}
}
