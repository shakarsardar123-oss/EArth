/// Abstraction for text-to-speech functionality.
///
/// Phase 2+ will implement platform-specific TTS.
/// Phase 1 provides the contract only.
abstract class TextToSpeechService {
  /// Whether TTS is available on this device.
  Future<bool> isAvailable();

  /// Speaks the given [text] aloud.
  ///
  /// [locale] defaults to Kurdish ('ku').
  Future<void> speak(String text, {String locale = 'ku'});

  /// Stops any in-progress speech.
  Future<void> stop();

  /// Whether the service is currently speaking.
  bool get isSpeaking;
}
