/// aura_assistant_pill_host.dart
/// AURA Assistant – Phase 5: Riverpod host that feeds the shared
/// [AuraAssistantPill] with REAL audio-activity signals.
///
/// This is the small additive glue that connects the existing pieces to the
/// pill without duplicating any of them:
///   • the unified session phase (voiceAssistantPhaseProvider),
///   • the REAL microphone level (voiceAssistantSoundLevelProvider) while the
///     USER is speaking (LISTENING),
///   • the REAL TTS output-activity level (voiceAssistantSpeakingLevelProvider)
///     while AURA is speaking (SPEAKING),
///   • the coordinator's stop()/bargeIn() for the pill's close/interrupt.
///
/// It picks WHICH real stream drives the waveform based on the current phase
/// — mic amplitude when the user talks, TTS activity when AURA talks — so a
/// single waveform reacts to whichever side is actually producing audio. It
/// never fabricates amplitude: outside those phases the amplitude is null and
/// the waveform falls back to its own state motion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/voice_session/voice_session_coordinator.dart';
import '../../core/voice_session/voice_session_providers.dart';
import 'aura_assistant_pill.dart';

/// Consumer widget that assembles the [AuraAssistantPill] from the existing
/// voice-session providers. Drop this into an in-app Stack overlay (or the
/// existing floating_aura overlay host) — it does not create a second overlay
/// mechanism itself.
class AuraAssistantPillHost extends ConsumerWidget {
  const AuraAssistantPillHost({
    super.key,
    this.transcript,
    this.hideWhenIdle = true,
  });

  /// Optional latest recognized / spoken snippet to show in the pill.
  final String? transcript;

  /// When true (default), renders nothing while the session is IDLE.
  final bool hideWhenIdle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(voiceAssistantPhaseProvider).value ??
        VoiceAssistantPhase.idle;

    if (hideWhenIdle && phase == VoiceAssistantPhase.idle) {
      return const SizedBox.shrink();
    }

    // Pick the REAL signal that matches who is currently producing audio.
    //   • LISTENING / WAKING → microphone RMS (normalised to 0..1)
    //   • SPEAKING           → TTS output activity (already 0..1)
    //   • otherwise          → null (waveform uses its own state motion)
    double? amplitude;
    switch (phase) {
      case VoiceAssistantPhase.waking:
      case VoiceAssistantPhase.listening:
        final raw = ref.watch(voiceAssistantSoundLevelProvider).value;
        amplitude = raw == null ? null : _normalizeMicLevel(raw);
        break;
      case VoiceAssistantPhase.speaking:
        // Already a 0..1 activity envelope from real TTS word events.
        amplitude = ref.watch(voiceAssistantSpeakingLevelProvider).value;
        break;
      case VoiceAssistantPhase.idle:
      case VoiceAssistantPhase.thinking:
      case VoiceAssistantPhase.error:
        amplitude = null;
        break;
    }

    final coordinator = ref.watch(voiceSessionCoordinatorProvider);

    return AuraAssistantPill(
      phase: phase,
      amplitude: amplitude,
      transcript: transcript,
      onClose: () => coordinator.stop(),
      onInterrupt: phase == VoiceAssistantPhase.speaking
          ? () => coordinator.bargeIn()
          : null,
    );
  }

  /// Normalise the platform microphone level to 0..1.
  ///
  /// speech_to_text's `onSoundLevelChange` reports a platform-dependent RMS
  /// value (Android typically ~ -2.0..10.0). This maps that observed range
  /// into 0..1 for the waveform. It is a linear rescale of a REAL measured
  /// value — no synthetic component.
  static double _normalizeMicLevel(double raw) {
    const double minLevel = -2.0;
    const double maxLevel = 10.0;
    final norm = (raw - minLevel) / (maxLevel - minLevel);
    return norm.clamp(0.0, 1.0);
  }
}
