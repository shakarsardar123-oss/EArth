import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/wakeword/wakeword_service.dart';
import '../../core/voice/voice_service_provider.dart';

/// Provider for the WakeWordService.
final wakeWordServiceProvider = Provider<WakeWordService>((ref) {
  final voiceService = ref.watch(voiceServiceImplProvider);
  return WakeWordService(voiceService: voiceService);
});

/// Provider that tracks whether wake word detection is active.
final wakeWordActiveProvider =
    StateNotifierProvider<WakeWordActiveNotifier, bool>((ref) {
  return WakeWordActiveNotifier(ref.watch(wakeWordServiceProvider));
});

/// StateNotifier for wake word activation state.
///
/// P4 FIX: _onWakeWord now sets state to false when the wake word
/// is detected (to indicate that wake word listening has paused
/// and full voice command listening should take over). The consumer
/// of this provider (e.g., the voice screen) can observe the
/// state transition and activate the full listening mode.
class WakeWordActiveNotifier extends StateNotifier<bool> {
  WakeWordActiveNotifier(this._wakeWordService) : super(false);

  final WakeWordService _wakeWordService;

  /// Start wake word listening.
  Future<void> start() async {
    await _wakeWordService.startListening(
      onWakeWordDetected: _onWakeWord,
    );
    state = true;
  }

  /// Stop wake word listening.
  Future<void> stop() async {
    await _wakeWordService.stopListening();
    state = false;
  }

  /// P4 FIX: When wake word is detected, pause wake word listening
  /// and signal the voice screen / dashboard to activate full
  /// command listening mode. The wake word service stops itself
  /// to avoid conflicts with the full listening session.
  void _onWakeWord() {
    // Signal that wake word was detected by briefly toggling state.
    // Listeners can observe the transition: true → false means
    // "wake word detected, switch to full listening".
    state = false;
    // Auto-stop wake word detection to avoid mic conflict
    // with the full listening session that will follow.
    _wakeWordService.stopListening();
  }

  @override
  void dispose() {
    _wakeWordService.dispose();
    super.dispose();
  }
}