/// Step 23 — Voice Adapter
///
/// Adapter implementing [VoiceRepository] by delegating to the canonical
/// AURA voice subsystem ([VoiceServiceImpl] + its STT/TTS sub-services).
///
/// This adapter creates NO second voice engine. It reuses the exact same
/// [VoiceServiceImpl], [SpeechRecognitionServiceImpl] and
/// [TextToSpeechServiceImpl] instances that the rest of the app (Live Mode,
/// Wake Word) already uses via `voiceServiceImplProvider`.
///
/// VoiceRepository:
///   recognizeSpeech()→Future<String?>
///   speak(String text, {String locale='ku'})→Future<void>
///   isSttAvailable()→Future<bool>
///   isTtsAvailable()→Future<bool>
///
/// Kurdish Sorani RTL first (STT: ckb_IQ per interface contract, TTS: ku).
///
/// Feedback-loop prevention: recognition relies on
/// [SpeechRecognitionServiceImpl]'s finalResult filtering (partials are
/// ignored), so only a single final transcription completes the Future.

import 'dart:async';

import '../../../../core/voice/speech_recognition_impl.dart';
import '../../../../core/voice/text_to_speech_impl.dart';
import '../../../../core/voice/voice_service_impl.dart';
import '../../domain/orchestration_domain.dart';

class VoiceAdapter implements VoiceRepository {
  /// Coordinating facade (state machine, feedback-loop prevention).
  final VoiceServiceImpl _voiceService;

  /// Underlying STT service — same instance the facade uses.
  /// Needed for availability checks (facade does not expose them).
  final SpeechRecognitionServiceImpl _speechRecognition;

  /// Underlying TTS service — same instance the facade uses.
  final TextToSpeechServiceImpl _textToSpeech;

  /// Default STT locale for Kurdish Sorani (per VoiceRepository contract).
  static const String _sttLocale = 'ckb_IQ';

  /// Wire the adapter to the real voice services (all injected).
  VoiceAdapter({
    required VoiceServiceImpl voiceService,
    required SpeechRecognitionServiceImpl speechRecognition,
    required TextToSpeechServiceImpl textToSpeech,
  })  : _voiceService = voiceService,
        _speechRecognition = speechRecognition,
        _textToSpeech = textToSpeech;

  @override
  Future<String?> recognizeSpeech() async {
    // Bridge the callback-based facade to a single-shot Future.
    // The facade delivers ONLY final results (partials are filtered by
    // SpeechRecognitionServiceImpl), so the first callback is the final
    // transcription. We then stop listening to release the mic.
    final completer = Completer<String?>();
    try {
      await _voiceService.startListening(
        locale: _sttLocale,
        onRecognized: (text) {
          if (!completer.isCompleted) {
            completer.complete(text.isEmpty ? null : text);
          }
        },
      );
    } catch (_) {
      // FAIL-CLOSED: STT error → no recognized speech.
      if (!completer.isCompleted) completer.complete(null);
    }

    final result = await completer.future;
    // Always release the microphone after a single recognition.
    try {
      await _voiceService.stopListening();
    } catch (_) {
      // Non-fatal — stopping failure must not surface as a crash.
    }
    return result;
  }

  @override
  Future<void> speak(String text, {String locale = 'ku'}) async {
    // Delegate to the facade so TTS shares the same state machine that
    // suppresses the STT feedback loop while AURA is speaking.
    await _voiceService.speak(text, locale: locale);
  }

  @override
  Future<bool> isSttAvailable() async {
    try {
      // initialize() is idempotent and returns whether STT is usable.
      return await _speechRecognition.initialize();
    } catch (_) {
      // FAIL-CLOSED: unknown → unavailable.
      return false;
    }
  }

  @override
  Future<bool> isTtsAvailable() async {
    try {
      return await _textToSpeech.isAvailable();
    } catch (_) {
      // FAIL-CLOSED: unknown → unavailable.
      return false;
    }
  }
}
