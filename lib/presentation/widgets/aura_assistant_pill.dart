/// aura_assistant_pill.dart
/// AURA Assistant – Phase 5: Dynamic-Island-style assistant pill
///
/// A long horizontal capsule shown near the TOP of the screen when a voice
/// session is active. It is an ORIGINAL AURA implementation for Android —
/// inspired only by the visual language of modern live-assistant
/// notifications, not copied from any platform's assets.
///
/// Visual language:
///   • long horizontal stadium shape, fully rounded (no sharp corners)
///   • AMOLED-black base with a subtle translucent "glass" overlay
///   • cyan + purple AURA glow that intensifies with activity
///   • compact height; does not take over the screen
///   • embeds the shared [AuraWaveForm] so the visualization is voice-reactive
///
/// It is intentionally a lightweight widget: the SAME widget can be placed in
/// an in-app Stack overlay OR inside the existing core/floating_aura system
/// overlay host — it does not create a second overlay mechanism itself.
library;

import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/voice_session/voice_session_coordinator.dart';
import 'aura_wave_form.dart';

/// Maps the unified session phase to the shared waveform's state.
AuraWaveFormState waveFormStateForPhase(VoiceAssistantPhase phase) {
  switch (phase) {
    case VoiceAssistantPhase.idle:
      return AuraWaveFormState.idle;
    case VoiceAssistantPhase.waking:
    case VoiceAssistantPhase.listening:
      return AuraWaveFormState.listening;
    case VoiceAssistantPhase.thinking:
      return AuraWaveFormState.processing;
    case VoiceAssistantPhase.speaking:
      return AuraWaveFormState.speaking;
    case VoiceAssistantPhase.error:
      return AuraWaveFormState.error;
  }
}

class AuraAssistantPill extends StatelessWidget {
  const AuraAssistantPill({
    super.key,
    required this.phase,
    this.amplitude,
    this.transcript,
    this.onClose,
    this.onInterrupt,
  });

  /// Current unified voice-assistant phase.
  final VoiceAssistantPhase phase;

  /// REAL normalised (0..1) audio-activity level for the waveform. While
  /// LISTENING this is the microphone level; while SPEAKING it is AURA's
  /// real TTS output activity (see [AuraAssistantPillHost] for how the
  /// correct real stream is selected per phase). null when no live signal
  /// applies — the waveform then uses its own state motion.
  final double? amplitude;

  /// Optional latest recognized / spoken snippet to show inside the pill.
  final String? transcript;

  /// Dismiss the whole session (pill close). null hides the close affordance.
  final VoidCallback? onClose;

  /// Barge-in: interrupt AURA while it is speaking. Only meaningful during
  /// [VoiceAssistantPhase.speaking].
  final VoidCallback? onInterrupt;

  static const Color _cyan = Color(0xFF00E5FF);
  static const Color _purple = Color(0xFF9B5CFF);

  @override
  Widget build(BuildContext context) {
    final glow = _glowForPhase(phase);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, left: 12, right: 12),
        child: Align(
          alignment: Alignment.topCenter,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              // Subtle glass blur behind the pill.
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                constraints: const BoxConstraints(minHeight: 56, maxWidth: 520),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  // AMOLED base with faint translucency for the glass feel.
                  color: const Color(0xF20A0A0F),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: _cyan.withOpacity(0.18 + 0.22 * glow),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _cyan.withOpacity(0.10 + 0.25 * glow),
                      blurRadius: 24,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: _purple.withOpacity(0.08 + 0.22 * glow),
                      blurRadius: 32,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusDot(phase: phase),
                    const SizedBox(width: 10),
                    // Compact embedded waveform — voice-reactive from REAL
                    // audio on BOTH sides: mic level while listening, TTS
                    // output activity while AURA speaks.
                    SizedBox(
                      width: 120,
                      height: 36,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: AuraWaveForm(
                          state: waveFormStateForPhase(phase),
                          amplitude: amplitude,
                          showPill: false,
                          barCount: 20,
                          maxBarHeight: 36,
                          minBarHeight: 3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            phase.statusText,
                            style: TextStyle(
                              color: _cyan.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (transcript != null &&
                              transcript!.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                transcript!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (phase == VoiceAssistantPhase.speaking &&
                        onInterrupt != null) ...[
                      const SizedBox(width: 8),
                      _PillIconButton(
                        icon: Icons.pause_rounded,
                        tooltip: 'Interrupt',
                        color: _purple,
                        onTap: onInterrupt!,
                      ),
                    ],
                    if (onClose != null) ...[
                      const SizedBox(width: 4),
                      _PillIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close',
                        color: Colors.white54,
                        onTap: onClose!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _glowForPhase(VoiceAssistantPhase phase) {
    switch (phase) {
      case VoiceAssistantPhase.idle:
        return 0.0;
      case VoiceAssistantPhase.waking:
        return 0.6;
      case VoiceAssistantPhase.listening:
        return (amplitude ?? 0.4).clamp(0.2, 1.0);
      case VoiceAssistantPhase.thinking:
        return 0.7;
      case VoiceAssistantPhase.speaking:
        // React to AURA's real TTS output activity when available.
        return (amplitude ?? 0.85).clamp(0.35, 1.0);
      case VoiceAssistantPhase.error:
        return 0.5;
    }
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.phase});
  final VoiceAssistantPhase phase;

  @override
  Widget build(BuildContext context) {
    final Color c = switch (phase) {
      VoiceAssistantPhase.error => const Color(0xFFFF5252),
      VoiceAssistantPhase.speaking => const Color(0xFF9B5CFF),
      VoiceAssistantPhase.thinking => const Color(0xFFFFC107),
      _ => const Color(0xFF00E5FF),
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c,
        boxShadow: [
          BoxShadow(color: c.withOpacity(0.6), blurRadius: 8, spreadRadius: 1),
        ],
      ),
    );
  }
}

class _PillIconButton extends StatelessWidget {
  const _PillIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: color),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
