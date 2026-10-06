import 'dart:async';

import 'package:flutter/services.dart';

import '../../services/voice/text_to_speech_service.dart';
import '../../core/errors/failures.dart';

/// Real [TextToSpeechService] implementation using the native Vekol
/// offline Sorani TTS bridge.
class TextToSpeechServiceImpl implements TextToSpeechService {
  TextToSpeechServiceImpl();

  static const MethodChannel _channel =
      MethodChannel('com.texo.texo/vekol_tts');

  bool _isSpeaking = false;

  // Vekol currently reports completion but does not expose PCM amplitude
  // callbacks to Flutter. Keep the existing activity envelope so the
  // speaking waveform remains responsive without pretending it is measured
  // acoustic amplitude.
  final _outputLevelController = StreamController<double>.broadcast();
  Timer? _levelDecayTimer;
  double _currentLevel = 0.0;

  Stream<double> get outputLevelStream => _outputLevelController.stream;

  void _emitLevel(double value) {
    _currentLevel = value.clamp(0.0, 1.0).toDouble();

    if (!_outputLevelController.isClosed) {
      _outputLevelController.add(_currentLevel);
    }
  }

  void _startLevelEnvelope() {
    _levelDecayTimer?.cancel();

    _emitLevel(0.75);

    _levelDecayTimer =
        Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (_currentLevel <= 0.02) {
        _currentLevel = 0.0;
      } else {
        _currentLevel *= 0.92;
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
    try {
      final ready = await _channel.invokeMethod<bool>('isReady');
      return ready == true;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> speak(String text, {String locale = 'ku'}) async {
    if (text.trim().isEmpty) {
      throw const VoiceFailure(
        message: 'TTS text is empty',
        code: 'TTS_EMPTY_TEXT',
      );
    }

    final ready = await isAvailable();

    if (!ready) {
      throw const VoiceFailure(
        message: 'Vekol TTS is not ready',
        code: 'TTS_NOT_READY',
      );
    }

    _isSpeaking = true;
    _startLevelEnvelope();

    try {
      await _channel.invokeMethod<bool>(
        'speak',
        <String, dynamic>{
          'text': text,
        },
      );
    } on PlatformException catch (e) {
      throw VoiceFailure(
        message: e.message ?? 'Vekol TTS failed',
        code: e.code.isEmpty ? 'TTS_SPEAK_FAILED' : e.code,
      );
    } catch (e) {
      throw VoiceFailure(
        message: 'Vekol TTS failed: $e',
        code: 'TTS_SPEAK_FAILED',
      );
    } finally {
      _isSpeaking = false;
      _stopLevelEnvelope();
    }
  }

  @override
  Future<void> stop() async {
    _isSpeaking = false;
    _stopLevelEnvelope();

    try {
      await _channel.invokeMethod<bool>('stop');
    } on PlatformException {
      // Native stop is best-effort. Flutter state is already reset above.
    } catch (_) {
      // Keep stop safe even if the native bridge is unavailable.
    }
  }

  @override
  bool get isSpeaking => _isSpeaking;

  void dispose() {
    _levelDecayTimer?.cancel();
    _levelDecayTimer = null;

    if (!_outputLevelController.isClosed) {
      _outputLevelController.close();
    }
  }
}
