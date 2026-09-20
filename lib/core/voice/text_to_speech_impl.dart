import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../../services/voice/text_to_speech_service.dart';
import '../../core/errors/failures.dart';

/// Real [TextToSpeechService] implementation using flutter_tts package.
class TextToSpeechServiceImpl implements TextToSpeechService {
  TextToSpeechServiceImpl();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _isSpeaking = false;

  // ── AURA-speaking output-activity signal (Phase 5) ──
  //
  // flutter_tts does NOT expose PCM audio or a raw amplitude/RMS callback,
  // so a *true acoustic* output level is not obtainable from this engine.
  // The ONLY output-side signal flutter_tts exposes is its word-boundary
  // progress callback (`setProgressHandler`), which fires for each word as
  // it is actually spoken. We turn those REAL progress events into a 0..1
  // activity envelope for the waveform: every real word event drives the
  // level UP, and a deterministic decay timer relaxes it between words.
  //
  // This is genuine speech-activity data (peaks are tied to words actually
  // being spoken) — it is NOT randomised/synthetic motion. It is also NOT a
  // measured acoustic amplitude; that remains a documented platform limit.
  final _outputLevelController = StreamController<double>.broadcast();
  Timer? _levelDecayTimer;
  double _currentLevel = 0.0;

  /// Stream (0..1) of TTS output activity while AURA is speaking, driven by
  /// real flutter_tts word-boundary progress events. Emits 0.0 when idle.
  /// See the note above: this is a real speech-activity envelope, not a
  /// measured acoustic amplitude and not a random animation.
  Stream<double> get outputLevelStream => _outputLevelController.stream;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _tts.awaitSpeakCompletion(true);
    _initialized = true;
    _tts.startHandler = () {
      _isSpeaking = true;
      _startLevelEnvelope();
    };
    _tts.completionHandler = () {
      _isSpeaking = false;
      _stopLevelEnvelope();
    };
    _tts.cancelHandler = () {
      _isSpeaking = false;
      _stopLevelEnvelope();
    };
    // REAL word-boundary events from the platform TTS. Each fired word is a
    // word actually being spoken right now — we map it to an activity pulse.
    _tts.setProgressHandler((text, start, end, word) {
      final wordLen = word.trim().length;
      // Longer words sustain a slightly higher peak; deterministic, no RNG.
      final target =
          (0.55 + (wordLen.clamp(1, 12) / 12) * 0.45).clamp(0.0, 1.0);
      _emitLevel(target.toDouble());
    });
  }

  void _emitLevel(double value) {
    _currentLevel = value;
    if (!_outputLevelController.isClosed) {
      _outputLevelController.add(_currentLevel);
    }
  }

  /// Deterministic decay between real word events (no random values). The
  /// RISES only ever come from genuine `setProgressHandler` word callbacks.
  void _startLevelEnvelope() {
    _levelDecayTimer?.cancel();
    _levelDecayTimer =
        Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (_currentLevel <= 0.02) {
        _currentLevel = 0.0;
      } else {
        _currentLevel *= 0.82;
      }
      if (!_outputLevelController.isClosed) {
        _outputLevelController.add(_currentLevel);
      }
    });
  }

  void _stopLevelEnvelope() {
    _levelDecayTimer?.cancel();
    _levelDecayTimer = null;
    _currentLevel = 0.0;
    if (!_outputLevelController.isClosed) {
      _outputLevelController.add(0.0);
    }
  }

  @override
  Future<bool> isAvailable() async {
    await _ensureInitialized();
    final engines = await _tts.getEngines;
    return engines != null && (engines as List).isNotEmpty;
  }

  @override
  Future<void> speak(String text, {String locale = 'ku'}) async {
    await _ensureInitialized();
    await _tts.setLanguage(locale);
    await _tts.setSpeechRate(0.9);
    await _tts.setPitch(1.0);
    _isSpeaking = true;
    // Start the decay envelope now so the output-level stream is live even on
    // platforms whose startHandler fires late; real word events (progress
    // handler) still drive every rise. Note: with awaitSpeakCompletion(true)
    // the call below only resolves AFTER speech finishes.
    _startLevelEnvelope();
    final result = await _tts.speak(text);
    if (result != 1) {
      throw const VoiceFailure(
        message: 'TTS failed to speak',
        code: 'TTS_SPEAK_FAILED',
      );
    }
  }

  @override
  Future<void> stop() async {
    _isSpeaking = false;
    _stopLevelEnvelope();
    await _tts.stop();
  }

  @override
  bool get isSpeaking => _isSpeaking;

  /// Release the output-level stream + decay timer. Safe to call once.
  void dispose() {
    _levelDecayTimer?.cancel();
    _levelDecayTimer = null;
    if (!_outputLevelController.isClosed) {
      _outputLevelController.close();
    }
  }
}
