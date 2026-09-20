/// Step 23 — Voice Repository Interface
///
/// Contract for STT/TTS integration.
/// Kurdish Sorani first: STT uses ckb_IQ, TTS uses ku.
/// The orchestrator must support voice-originated requests without requiring
/// the user to interact manually with the screen.

abstract class VoiceRepository {
  /// Start speech-to-text recognition.
  /// Uses locale ckb_IQ for Kurdish Sorani.
  Future<String?> recognizeSpeech();

  /// Speak text aloud using TTS.
  /// Uses locale ku for Kurdish Sorani.
  Future<void> speak(String text, {String locale = 'ku'});

  /// Whether the STT subsystem is available.
  Future<bool> isSttAvailable();

  /// Whether the TTS subsystem is available.
  Future<bool> isTtsAvailable();
}
