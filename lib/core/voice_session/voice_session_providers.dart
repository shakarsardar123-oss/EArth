/// voice_session_providers.dart
/// TEXO – Phase 5: Riverpod wiring for the voice-assistant session
///
/// Exposes the [VoiceSessionCoordinator] and the user-facing TEXO Voice
/// settings, reusing the EXISTING providers for the wake word, the shared
/// VoiceService, and the Live Mode orchestrator (no duplicate engines).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../wakeword/wakeword_provider.dart' show wakeWordServiceProvider;
import '../voice/voice_service_provider.dart' show voiceServiceImplProvider;
import '../live_mode/live_mode_providers.dart'
    show liveModeOrchestratorProvider, liveSessionTimeoutProvider;
import '../audio/audio_providers.dart'
    show
        acousticWakeWordEngineProvider,
        bargeInControllerProvider,
        outputLevelMonitorProvider;
import 'voice_session_coordinator.dart';

// ── TEXO Voice settings (persisted by the UI layer as needed) ──

/// Wake Word ON/OFF.
final wakeWordEnabledProvider = StateProvider<bool>((ref) => true);

/// Continuous-conversation ON/OFF. When ON, the session loops across turns
/// (the default assistant behaviour). When OFF, callers may choose to end the
/// session after a single answer (enforced at the call site, not here).
final continuousConversationProvider = StateProvider<bool>((ref) => true);

/// Voice responses (TTS) ON/OFF. Consumed by the voice UI.
final voiceResponsesEnabledProvider = StateProvider<bool>((ref) => true);

/// Inactivity/session timeout. null = no timeout (session ends only on an
/// explicit exit command or user dismissal). This re-exports the Live Mode
/// timeout provider so the setting and the orchestrator share one source of
/// truth (no duplicate state).
final sessionTimeoutProvider = liveSessionTimeoutProvider;

/// The fixed wake phrase, shown (read-only) in settings.
const String kTexoWakePhrase = 'Hey TEXO / تێکسۆ';

// ── Coordinator ──

/// The single [VoiceSessionCoordinator]. Reuses the existing wake-word
/// service, shared VoiceService (for the real mic sound-level stream), and
/// the existing Live Mode orchestrator.
final voiceSessionCoordinatorProvider =
    Provider<VoiceSessionCoordinator>((ref) {
  final wakeWord = ref.watch(wakeWordServiceProvider);
  final voiceService = ref.watch(voiceServiceImplProvider);
  final orchestrator = ref.watch(liveModeOrchestratorProvider);
  final wakeEnabled = ref.watch(wakeWordEnabledProvider);

  final coordinator = VoiceSessionCoordinator(
    wakeWordService: wakeWord,
    voiceService: voiceService,
    orchestrator: orchestrator,
    wakeWordEnabled: wakeEnabled,
    // Final Voice Phase: real audio pipeline collaborators. On non-Android /
    // tests these resolve to safe stubs (unavailable), so behaviour degrades
    // gracefully to the existing STT wake + TTS-envelope waveform.
    wakeEngine: ref.watch(acousticWakeWordEngineProvider),
    bargeInController: ref.watch(bargeInControllerProvider),
    outputLevelMonitor: ref.watch(outputLevelMonitorProvider),
  );

  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Convenience stream provider of the unified phase for widgets/pills.
final voiceAssistantPhaseProvider =
    StreamProvider<VoiceAssistantPhase>((ref) {
  final coordinator = ref.watch(voiceSessionCoordinatorProvider);
  return coordinator.phaseStream;
});

/// Convenience stream provider of the REAL microphone sound level (0..1-ish
/// raw platform value) for the pill waveform's LISTENING reactivity.
final voiceAssistantSoundLevelProvider = StreamProvider<double>((ref) {
  final coordinator = ref.watch(voiceSessionCoordinatorProvider);
  return coordinator.soundLevelStream;
});

/// Convenience stream provider of the REAL TTS output activity (0..1) for the
/// pill waveform's SPEAKING reactivity. Driven by genuine flutter_tts
/// word-boundary progress events (not fabricated). See the coordinator's
/// speakingLevelStream for the platform-limitation note.
final voiceAssistantSpeakingLevelProvider = StreamProvider<double>((ref) {
  final coordinator = ref.watch(voiceSessionCoordinatorProvider);
  return coordinator.speakingLevelStream;
});

/// Preferred SPEAKING waveform source: the GENUINE acoustic output level when
/// a real output monitor is active (Android Visualizer RMS), otherwise the
/// flutter_tts word-activity envelope. Widgets should prefer this provider.
final voiceAssistantOutputLevelProvider = StreamProvider<double>((ref) {
  final coordinator = ref.watch(voiceSessionCoordinatorProvider);
  return coordinator.outputLevelStream;
});
