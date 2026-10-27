import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../../services/voice/voice_service.dart';
import '../../core/voice/speech_recognition_impl.dart';
import '../../core/voice/text_to_speech_impl.dart';
import '../../core/tts/vekol_tts_service.dart';

/// Real [VoiceService] implementation coordinating STT and TTS.
class VoiceServiceImpl implements VoiceService {
  VoiceServiceImpl({
    SpeechRecognitionServiceImpl? speechRecognition,
    TextToSpeechServiceImpl? textToSpeech,
  })  : _speechRecognition = speechRecognition ?? SpeechRecognitionServiceImpl(),
        _textToSpeech = textToSpeech ?? TextToSpeechServiceImpl();

  final SpeechRecognitionServiceImpl _speechRecognition;
  final TextToSpeechServiceImpl _textToSpeech;
  final AudioPlayer _micBeepPlayer = AudioPlayer();
  final AudioPlayer _ttsPlayer = AudioPlayer();
  bool _stopRequested = false;
  Completer<void>? _playDone;

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

  Future<void> _playMicBeep() async {
    try {
      await _micBeepPlayer.stop();
      await _micBeepPlayer.setReleaseMode(ReleaseMode.stop);

      final completed = _micBeepPlayer.onPlayerComplete.first;

      await _micBeepPlayer.play(
        AssetSource('audio/texo_mic_beep.mp3'),
      );

      await completed;
    } catch (_) {
      // Beep failure must never block microphone activation.
    }
  }

  @override
  Future<void> startListening({
    required void Function(String text) onRecognized,
    String? locale = 'ku',
  }) async {
    _onRecognized = onRecognized;

    await _playMicBeep();

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
      final lc = locale.toLowerCase();
      if (lc.startsWith('ku') || lc.startsWith('ckb')) {
        if (await _speakKurdish(text)) {
          _setState(VoiceState.idle);
          return;
        }
      }
      await _textToSpeech.speak(text, locale: locale);
    } catch (e) {
      _setState(VoiceState.error);
      return;
    }
    _setState(VoiceState.idle);
  }

  /// Speaks Kurdish text with the offline Vekol model, sentence by sentence.
  /// Returns false only if nothing could be spoken (caller falls back).
  Future<bool> _speakKurdish(String text) async {
    _stopRequested = false;
    final sentences = text
        .split(RegExp(r'(?<=[.!?؟\n])\s*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (sentences.isEmpty) return false;

    var spokeAny = false;
    try {
      for (final sentence in sentences) {
        if (_stopRequested) break;
        final waveform =
            await VekolTtsService.instance.synthesizeText(sentence);
        if (_stopRequested) break;
        final wav = VekolTtsService.instance.waveformToWav(waveform);
        await _playWav(wav);
        spokeAny = true;
      }
      return true;
    } catch (_) {
      return spokeAny;
    }
  }

  Future<void> _playWav(Uint8List wav) async {
    final done = Completer<void>();
    _playDone = done;
    final sub = _ttsPlayer.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    try {
      await _ttsPlayer.play(BytesSource(wav));
      await done.future.timeout(const Duration(minutes: 2), onTimeout: () {});
    } finally {
      await sub.cancel();
      _playDone = null;
    }
  }

  @override
  Future<void> stopSpeaking() async {
    _stopRequested = true;
    try {
      await _ttsPlayer.stop();
    } catch (_) {}
    final pd = _playDone;
    if (pd != null && !pd.isCompleted) pd.complete();
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
    _micBeepPlayer.dispose();
    _ttsPlayer.dispose();
    _stateController.close();
    _resultController.close();
    _soundLevelController.close();
    _textToSpeech.dispose();
  }
}
