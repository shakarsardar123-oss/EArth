import 'dart:async';

import '../../services/voice/voice_service.dart';
import '../../core/voice/speech_recognition_impl.dart';
import '../../core/voice/text_to_speech_impl.dart';

/// Real [VoiceService] implementation coordinating STT and TTS.
class VoiceServiceImpl implements VoiceService {
  VoiceServiceImpl({
    SpeechRecognitionServiceImpl? speechRecognition,
    TextToSpeechServiceImpl? textToSpeech,
  })  : _speechRecognition = speechRecognition ?? SpeechRecognitionServiceImpl(),
        _textToSpeech = textToSpeech ?? TextToSpeechServiceImpl();

  final SpeechRecognitionServiceImpl _speechRecognition;
  final TextToSpeechServiceImpl _textToSpeech;

  VoiceState _state = VoiceState.idle;
  final _stateController = StreamController<VoiceState>.broadcast();
  final _resultController = StreamController<String>.broadcast();
  final _soundLevelController = StreamController<double>.broadcast();
  void Function(String)? _onRecognized;

  @override
  VoiceState get state => _state;

  @override
  Stream<VoiceState> get stateStream => _stateController.stream;

  /// Stream of recognized text results.
  Stream<String>? get resultStream => _resultController.stream;

  /// Stream of REAL microphone sound levels emitted by the platform speech
  /// recognizer while listening (see SpeechRecognitionServiceImpl
  /// `onSoundLevelChange`). This is a genuine audio-amplitude signal — not a
  /// synthesized/random value — consumed by the assistant pill waveform so
  /// its LISTENING animation reacts to the user's actual voice.
  ///
  /// NOTE: This covers the *input* (microphone / STT) path only. The
  /// separate [speakingLevelStream] covers AURA's *output* (TTS) path.
  Stream<double> get soundLevelStream => _soundLevelController.stream;

  /// Stream of REAL TTS output activity (0..1) while AURA is SPEAKING,
  /// forwarded verbatim from the underlying TextToSpeechServiceImpl. Its
  /// peaks are driven by genuine flutter_tts word-boundary progress events
  /// (words actually being spoken), with a deterministic decay between
  /// words — it is NOT a random/synthetic animation.
  ///
  /// HONESTY NOTE: flutter_tts exposes no PCM/RMS amplitude callback, so
  /// this is a real speech-*activity* envelope, not a measured acoustic
  /// amplitude. The waveform's SPEAKING reactivity is driven by this real
  /// TTS event stream, not by fabricated values.
  Stream<double> get speakingLevelStream => _textToSpeech.outputLevelStream;

  void _setState(VoiceState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
    }
  }

  @override
  Future<void> startListening({
    required void Function(String text) onRecognized,
    String? locale = 'ku',
  }) async {
    _onRecognized = onRecognized;
    _setState(VoiceState.listening);

    try {
      await _speechRecognition.startListening(
        onResult: (text) {
          _setState(VoiceState.processing);
          _resultController.add(text);
          _onRecognized?.call(text);
        },
        onSoundLevel: (level) {
          if (!_soundLevelController.isClosed) {
            _soundLevelController.add(level);
          }
        },
        locale: locale,
      );
    } catch (e) {
      _setState(VoiceState.error);
    }
  }

  /// Alternative startListening with localeId param for wakeword compatibility.
  Future<void> startListeningWithLocaleId({
    required String localeId,
    required void Function(String text) onResult,
  }) async {
    return startListening(onRecognized: onResult, locale: localeId);
  }

  @override
  Future<void> stopListening() async {
    try {
      await _speechRecognition.stopListening();
    } finally {
      if (_state == VoiceState.listening) {
        _setState(VoiceState.idle);
      }
    }
  }

  @override
  Future<void> speak(String text, {String locale = 'ku'}) async {
    _setState(VoiceState.speaking);
    try {
      await _textToSpeech.speak(text, locale: locale);
    } catch (e) {
      _setState(VoiceState.error);
      return;
    }
    _setState(VoiceState.idle);
  }

  @override
  Future<void> stopSpeaking() async {
    try {
      await _textToSpeech.stop();
    } finally {
      if (_state == VoiceState.speaking) {
        _setState(VoiceState.idle);
      }
    }
  }

  /// Dispose resources.
  void dispose() {
    _stateController.close();
    _resultController.close();
    _soundLevelController.close();
    _textToSpeech.dispose();
  }
}
