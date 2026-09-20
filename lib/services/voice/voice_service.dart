import 'speech_recognition_service.dart';
import 'text_to_speech_service.dart';

/// Current state of the voice subsystem.
enum VoiceState {
  idle,
  listening,
  processing,
  speaking,
  error;

  bool get isActive => this == VoiceState.listening ||
      this == VoiceState.processing ||
      this == VoiceState.speaking;
}

/// Unified facade that coordinates [SpeechRecognitionService]
/// and [TextToSpeechService].
///
/// Phase 1 provides the contract only.
abstract class VoiceService {
  /// The current [VoiceState].
  VoiceState get state;

  /// Stream of state changes.
  Stream<VoiceState> get stateStream;

  /// Starts listening; the recognized text will be delivered via
  /// [onRecognized]. A `null` [locale] means the device's system speech
  /// locale (used by wake-word detection so "Hey AURA" can be recognized
  /// independently of the UI language).
  Future<void> startListening({
    required void Function(String text) onRecognized,
    String? locale = 'ku',
  });

  /// Stops listening.
  Future<void> stopListening();

  /// Speaks [text] aloud.
  Future<void> speak(String text, {String locale = 'ku'});

  /// Stops any in-progress speech.
  Future<void> stopSpeaking();
}
