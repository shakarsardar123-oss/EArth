/// acoustic_wake_word_engine.dart
/// AURA Assistant – Final Voice Phase: genuine acoustic wake-word interface.
///
/// Defines the contract for a REAL on-device keyword-spotting (KWS) engine
/// that detects "Hey AURA" acoustically — WITHOUT continuously running full
/// speech-to-text. The engine runs a small always-on model over the mic and
/// emits a [WakeEvent] (with confidence, when the model provides it) only when
/// the wake phrase is spotted.
///
/// TWO IMPLEMENTATIONS ARE PROVIDED:
///  * [NativeAcousticWakeWordEngine] – bridges to a native KWS runner over an
///    EventChannel. This is the real always-on path (low-power, screen-off
///    capable inside a foreground microphone service). It requires a bundled
///    KWS MODEL ASSET for the "Hey AURA" phrase (e.g. an openWakeWord / Vosk
///    keyword / Porcupine `.ppn` model). That model asset is NOT bundled in
///    this repository (licensing + size), so the native runner reports
///    [WakeEngineStatus.modelMissing] until a model is added. We do NOT fake a
///    detection in that state — see the report's "remaining blockers".
///  * [StubAcousticWakeWordEngine] – reports unavailable; the existing
///    STT-keyword WakeWordService remains the documented fallback so the
///    product still wakes, just not in a low-power always-on manner.
///
/// The [WakeWordService] STT keyword-spotter is kept ONLY as the explicit,
/// documented fallback. This interface is the primary mechanism once a model
/// asset is provided.
library;

import 'dart:async';

import 'package:flutter/services.dart';

import 'wake_word_debouncer.dart';

/// Health/capability of a wake-word engine.
enum WakeEngineStatus {
  /// Not yet initialised.
  uninitialized,

  /// Initialised and actively listening for the phrase.
  listening,

  /// Engine present but the KWS model asset is missing (real blocker).
  modelMissing,

  /// Engine or platform unsupported.
  unavailable,
}

/// A confirmed wake detection.
class WakeEvent {
  const WakeEvent({required this.confidence, required this.timestamp});

  /// 0..1 confidence. 1.0 when the engine does not report a score.
  final double confidence;
  final DateTime timestamp;
}

/// Contract for a genuine acoustic wake-word detector.
abstract class AcousticWakeWordEngine {
  /// Stream of accepted wake events (already debounced by the engine).
  Stream<WakeEvent> get wakeStream;

  /// Current status.
  WakeEngineStatus get status;

  /// Load the model and prepare the runner. Returns the resolved status.
  Future<WakeEngineStatus> initialize();

  /// Begin low-power listening.
  Future<void> start();

  /// Stop listening (keeps the model loaded).
  Future<void> stop();

  /// Release all resources.
  Future<void> dispose();
}

/// Native EventChannel-backed KWS engine. Applies the shared
/// [WakeWordDebouncer] on top of native detections for one-utterance-one-wake
/// + cooldown safety, regardless of how chatty the native model is.
class NativeAcousticWakeWordEngine implements AcousticWakeWordEngine {
  NativeAcousticWakeWordEngine({
    EventChannel? eventChannel,
    MethodChannel? controlChannel,
    WakeWordDebouncer? debouncer,
    DateTime Function()? clock,
  })  : _events = eventChannel ??
            const EventChannel('com.aura.aura_assistant/wake.events'),
        _control = controlChannel ??
            const MethodChannel('com.aura.aura_assistant/wake'),
        _debouncer = debouncer ?? WakeWordDebouncer(),
        _clock = clock ?? DateTime.now;

  final EventChannel _events;
  final MethodChannel _control;
  final WakeWordDebouncer _debouncer;
  final DateTime Function() _clock;

  final _controller = StreamController<WakeEvent>.broadcast();
  StreamSubscription<dynamic>? _sub;
  WakeEngineStatus _status = WakeEngineStatus.uninitialized;

  @override
  Stream<WakeEvent> get wakeStream => _controller.stream;

  @override
  WakeEngineStatus get status => _status;

  @override
  Future<WakeEngineStatus> initialize() async {
    try {
      final res = await _control.invokeMethod<String>('initialize');
      _status = _parse(res ?? 'unavailable');
    } on PlatformException {
      _status = WakeEngineStatus.unavailable;
    } on MissingPluginException {
      _status = WakeEngineStatus.unavailable;
    }
    return _status;
  }

  @override
  Future<void> start() async {
    if (_status == WakeEngineStatus.uninitialized) {
      await initialize();
    }
    if (_status == WakeEngineStatus.modelMissing ||
        _status == WakeEngineStatus.unavailable) {
      // Do NOT fake listening when there is no model / platform support.
      return;
    }
    try {
      await _control.invokeMethod('start');
      _status = WakeEngineStatus.listening;
      _sub ??= _events.receiveBroadcastStream().listen(
        (event) {
          final confidence = (event is Map)
              ? ((event['confidence'] as num?)?.toDouble() ?? 1.0)
              : (event is num ? event.toDouble() : 1.0);
          final now = _clock();
          if (_debouncer.shouldAccept(now: now, confidence: confidence)) {
            if (!_controller.isClosed) {
              _controller
                  .add(WakeEvent(confidence: confidence, timestamp: now));
            }
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _control.invokeMethod('stop');
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  static WakeEngineStatus _parse(String s) {
    switch (s) {
      case 'listening':
        return WakeEngineStatus.listening;
      case 'ready':
        return WakeEngineStatus.listening;
      case 'model_missing':
        return WakeEngineStatus.modelMissing;
      case 'uninitialized':
        return WakeEngineStatus.uninitialized;
      default:
        return WakeEngineStatus.unavailable;
    }
  }
}

/// Safe fallback engine — never fabricates a wake.
class StubAcousticWakeWordEngine implements AcousticWakeWordEngine {
  final _controller = StreamController<WakeEvent>.broadcast();

  @override
  Stream<WakeEvent> get wakeStream => _controller.stream;

  @override
  WakeEngineStatus get status => WakeEngineStatus.unavailable;

  @override
  Future<WakeEngineStatus> initialize() async => WakeEngineStatus.unavailable;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
