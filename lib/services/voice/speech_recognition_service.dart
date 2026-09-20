/// Abstraction for speech-to-text functionality.
///
/// Phase 2+ will implement platform-specific speech recognition.
/// Phase 1 provides the contract only.
abstract class SpeechRecognitionService {
  /// Whether speech recognition is available on this device.
  Future<bool> isAvailable();

  /// Starts listening for speech input.
  ///
  /// [onResult] is called with the recognized text.
  /// [locale] specifies the language for recognition (e.g. 'ku').
  Future<void> startListening({
    required void Function(String text) onResult,
    String locale = 'ku',
  });

  /// Stops listening for speech input.
  Future<void> stopListening();

  /// Whether the service is currently listening.
  bool get isListening;
}
