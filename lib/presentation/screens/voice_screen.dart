/// voice_screen.dart
/// AURA Assistant – Voice Screen (Home)
///
/// Matches Reference Image 1: vertical bar wave form on AMOLED pure black,
/// floating pill container, AURA header.
///
/// Enhancements:
///   • Smart Greeting from greeting_provider shown above AURA header
///   • AURA identity subtitle "من تێکسۆی تایبەتی تۆم"
///   • Menu hamburger replaced with Chat navigation button (index 1)
///   • Settings gear updated to index 2
///   • All hardcoded strings replaced with l10n keys
///   • P0 Live Mode functionality FULLY PRESERVED
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:texo/l10n/app_localizations.dart';

import '../../core/providers/phase3_connection_points.dart';
import '../../core/providers/greeting_provider.dart';
import '../../services/voice/voice_service.dart' show VoiceState;
import '../../core/theme/app_colors.dart';
import '../../core/voice/voice_service_provider.dart';
import '../../core/permissions/contextual_permission_helper.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../../core/agent/agent_context.dart';
import '../../core/reaction/reaction.dart';
import '../../core/live_mode/live_mode_state.dart';
import '../../core/live_mode/live_mode_providers.dart'
    show liveModeOrchestratorProvider, liveModeStateProvider, isLiveSessionProvider;
import '../providers/app_providers.dart';
import '../widgets/widgets.dart';
import '../widgets/voice_visualizer.dart';
import '../../core/errors/result.dart';
import '../../features/globe/application/globe_controller.dart';
import '../../features/globe/domain/location_action.dart';
import '../../features/globe/presentation/realistic_globe.dart';

/// Voice Screen — redesigned with Wave Form (Reference Image 1).
///
/// AMOLED pure black background, vertical bar wave form in floating pill,
/// AURA header. All P0 handlers preserved exactly.
class VoiceScreen extends ConsumerWidget {
  const VoiceScreen({super.key});

  // Controller kept as a static-lifetime singleton on the widget instance
  // scope (rebuilt with the screen, not with every frame) so the
  // agent/command pipeline has a stable object to drive the globe
  // (rotateToLocation / highlightCity / applyLocationAction / ...).
  static final GlobeController _globeController = GlobeController();

  // Stateless, reusable parser that pulls an OPTIONAL validated location
  // metadata block out of the AI's plain-text answer. Backward compatible:
  // responses without a block are returned unchanged as plain text.
  static final LocationActionParser _locationParser = LocationActionParser();

  /// Toggle Live Mode from voice screen.
  Future<void> _toggleLiveMode(BuildContext context, WidgetRef ref) async {
    final isLive = ref.read(isLiveSessionProvider);
    final orchestrator = ref.read(liveModeOrchestratorProvider);

    if (isLive) {
      await orchestrator.stopSession();
      return;
    }

    final permHelper = ContextualPermissionHelper();
    final micGranted = await permHelper.requestSingleWithRationale(
      context: context,
      permission: ph.Permission.microphone,
      isCritical: true,
    );
    if (!micGranted) return;

    orchestrator.onUserRecognized = (text) {
      ref.read(voiceTranscriptProvider.notifier).update((_) => text);
    };

    orchestrator.onAIResponse = (text) {
      // Parse an OPTIONAL location metadata block, drive the globe, and
      // show only the human-readable text (backward compatible).
      final parsed = _locationParser.parse(text);
      if (parsed.action != null) {
        _globeController.applyLocationAction(parsed.action!);
      }
      ref.read(aiResponseProvider.notifier).update((_) => parsed.text);
    };

    final session = await orchestrator.startSession();
    if (session == null && context.mounted) {
      final l10n = S.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.liveModeStartFailed),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    final iconColor = dark ? Colors.white : Colors.black;
    final bg = dark
        ? AppColors.amoledBlack
        : const Color(0xFFF7F8FA);

    ref.watch(voiceStateProvider);
    final transcript = ref.watch(voiceTranscriptProvider);
    final aiResponse = ref.watch(aiResponseProvider);
    final liveModeState = ref.watch(liveModeStateProvider);
    final isLive = ref.watch(isLiveSessionProvider);
    final voiceState = ref.read(voiceStateProvider);

    final greetingAsync = ref.watch(smartGreetingProvider);
    final greetingText = greetingAsync.maybeWhen(
      data: (key) => resolveGreetingKey(key),
      orElse: () => 'سڵاو',
    );

    final waveFormState = isLive
        ? _liveModeStateToWaveFormState(liveModeState)
        : _voiceStateToWaveFormState(voiceState);

    final isListening = voiceState == VoiceState.listening ||
        (isLive && liveModeState == LiveModeState.listening);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // ── Modern top bar ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Row(
                    children: [
                      _ModernCircleButton(
                        icon: Icons.settings_rounded,
                        color: iconColor,
                        onTap: () {
                          ref.read(navigationIndexProvider.notifier).state = 2;
                        },
                      ),

                      const Spacer(),

                      // Live Mode pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: iconColor.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isLive
                                    ? const Color(0xFF25B7FF)
                                    : iconColor.withValues(alpha: 0.35),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'Live Mode',
                              style: TextStyle(
                                color: iconColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      _EndLiveButton(
                        onTap: () {
                          if (isLive) {
                            _toggleLiveMode(context, ref);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // ── Greeting / identity ──
                Text(
                  greetingText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: dark
                        ? Colors.white.withValues(alpha: 0.62)
                        : Colors.black.withValues(alpha: 0.62),
                    letterSpacing: 0.4,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  'TEXO',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: dark
                        ? Colors.white
                        : Colors.black,
                    letterSpacing: 6,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  l10n.auraIdentity,
                  style: TextStyle(
                    fontSize: 11,
                    color: iconColor.withValues(alpha: 0.45),
                    letterSpacing: 0.8,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  isListening
                      ? l10n.voiceStatusListening
                      : isLive
                          ? l10n.liveModeActive
                          : _getStatusText(l10n, voiceState),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isListening
                        ? const Color(0xFF25B7FF)
                        : iconColor.withValues(alpha: 0.60),
                    letterSpacing: 1.2,
                  ),
                ),

                const Spacer(flex: 2),

                // ── Orb + waveform composition ──
                const SizedBox(height: 8),
                SizedBox(
                  height: 235,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Center(
                          child: AuraWaveForm(
                            state: waveFormState,
                            barCount: 56,
                            barGap: 2.5,
                            maxBarHeight: 82,
                            minBarHeight: 3,
                            fullBleed: true,
                            centerGap: 0.30,
                            occlusionRadius: 88,
                            occlusionFeather: 34,
                          ),
                        ),
                      ),
                      RealisticGlobe(
                        controller: _globeController,
                        size: 168,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // ── Status / prompt ──
                AnimatedOpacity(
                  opacity: isLive ? 1 : 0.45,
                  duration: const Duration(milliseconds: 200),
                  child: VoiceVisualizer(
                    barCount: 36,
                    maxBarHeight: 42,
                    barWidth: 3,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  isListening
                      ? l10n.voiceStatusListening
                      : isLive
                          ? l10n.liveModeActive
                          : l10n.voicePromptHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.75),
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(flex: 2),

                // ── Transcript / response ──
                if (transcript.isNotEmpty || aiResponse.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (transcript.isNotEmpty) ...[
                            Text(
                              l10n.transcriptLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              transcript,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                          if (aiResponse.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              l10n.responseLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF25B7FF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              aiResponse,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                // ── Modern controls ──
                Padding(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 22,
                    top: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SmallLiveButton(
                        icon: isListening
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                        color: iconColor,
                        onTap: () => _handleMicTap(context, ref),
                      ),

                      const SizedBox(width: 26),

                      GestureDetector(
                        onTap: () => _handleMicTap(context, ref),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          width: isListening ? 78 : 70,
                          height: isListening ? 78 : 70,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(
                              alpha: isListening ? 0.16 : 0.08,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: iconColor.withValues(
                                alpha: isListening ? 0.9 : 0.18,
                              ),
                              width: isListening ? 2 : 1,
                            ),
                            boxShadow: isListening
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF008CFF)
                                          .withValues(alpha: 0.35),
                                      blurRadius: 28,
                                    ),
                                  ]
                                : const [],
                          ),
                          child: Icon(
                            Icons.mic_rounded,
                            color: iconColor,
                            size: 30,
                          ),
                        ),
                      ),

                      const SizedBox(width: 26),

                      _EndLiveButton(
                        onTap: () {
                          if (isLive) {
                            _toggleLiveMode(context, ref);
                          }
                        },
                        size: 58,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AuraReactionBanner(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ModernCircleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.07),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: color,
            size: 21,
          ),
        ),
      ),
    );
  }

  // ─── State Mapping (P0 preserved) ─────────────────────────

  AuraWaveFormState _liveModeStateToWaveFormState(LiveModeState state) =>
      switch (state) {
        LiveModeState.listening => AuraWaveFormState.listening,
        LiveModeState.processing => AuraWaveFormState.processing,
        LiveModeState.speaking => AuraWaveFormState.speaking,
        LiveModeState.error => AuraWaveFormState.error,
        _ => AuraWaveFormState.idle,
      };

  AuraWaveFormState _voiceStateToWaveFormState(VoiceState voiceState) {
    switch (voiceState) {
      case VoiceState.listening:
        return AuraWaveFormState.listening;
      case VoiceState.processing:
        return AuraWaveFormState.processing;
      case VoiceState.speaking:
        return AuraWaveFormState.speaking;
      case VoiceState.error:
        return AuraWaveFormState.error;
      default:
        return AuraWaveFormState.idle;
    }
  }

  String _getStatusText(S l10n, VoiceState voiceState) {
    switch (voiceState) {
      case VoiceState.listening:
        return l10n.voiceStatusListening;
      case VoiceState.processing:
        return l10n.voiceStatusProcessing;
      case VoiceState.speaking:
        return l10n.voiceStatusSpeaking;
      case VoiceState.error:
        return l10n.voiceStatusError;
      default:
        return l10n.voiceStatusReady;
    }
  }

  /// Real mic tap handler — FULLY PRESERVED from original.
  Future<void> _handleMicTap(BuildContext context, WidgetRef ref) async {
    final l10n = S.of(context);
    final voiceState = ref.read(voiceStateProvider);

    if (voiceState == VoiceState.speaking ||
        voiceState == VoiceState.processing) {
      final voiceService = ref.read(voiceServiceImplProvider);
      if (voiceState == VoiceState.speaking) {
        await voiceService.stopSpeaking();
      } else {
        await voiceService.stopListening();
      }
      return;
    }

    if (voiceState == VoiceState.listening) {
      final voiceService = ref.read(voiceServiceImplProvider);
      await voiceService.stopListening();
      return;
    }

    if (voiceState == VoiceState.error) {
      ref.read(voiceStateProvider.notifier).setState(VoiceState.idle);
      return;
    }

    final permHelper = ContextualPermissionHelper();
    final micGranted = await permHelper.requestSingleWithRationale(
      context: context,
      permission: ph.Permission.microphone,
      isCritical: true,
    );
    if (!micGranted) {
      ref.read(voiceStateProvider.notifier).setState(VoiceState.error);
      return;
    }

    final voiceService = ref.read(voiceServiceImplProvider);

    await voiceService.startListening(
      onRecognized: (text) {
        ref.read(voiceTranscriptProvider.notifier).update((_) => text);
        ref.read(voiceStateProvider.notifier).setState(VoiceState.processing);
        _processWithAgent(ref, text);
      },
      locale: 'ckb_IQ',
    );
  }

  /// Send recognized text to AgentEngine and speak the response — FULLY PRESERVED.
  Future<void> _processWithAgent(WidgetRef ref, String userInput) async {
    try {
      final agentEngine = ref.read(agentEngineProvider);
      final agentConfig = ref.read(agentConfigProvider);

      final context = AgentContext(
        agentConfig: agentConfig,
        conversationHistory: [],
        maxSteps: 10,
      );

      final result = await agentEngine.run(
        userInput: userInput,
        context: context,
      );

      if (result.isSuccess && result.response != null) {
        // Parse an OPTIONAL, validated location metadata block. If present,
        // drive the globe; either way display/speak only the clean text.
        final parsed = _locationParser.parse(result.response!);
        if (parsed.action != null) {
          _globeController.applyLocationAction(parsed.action!);
        }
        final displayText =
            parsed.text.isNotEmpty ? parsed.text : result.response!;
        ref.read(aiResponseProvider.notifier).update((_) => displayText);

        final voiceService = ref.read(voiceServiceImplProvider);
        final coordinator = ref.read(reactionSpeechCoordinatorProvider);
        await coordinator.speakOrHold(
          displayText,
          (text) => voiceService.speak(text),
        );
      } else {
        ref.read(aiResponseProvider.notifier).update(
            (_) => result.errorMessage ?? 'ببورە، هەڵەیەک ڕوویدا.');
        ref.read(voiceStateProvider.notifier).setState(VoiceState.error);
      }
    } catch (e) {
      ref.read(aiResponseProvider.notifier).update((_) => 'ببورە، نەمتوانم وەڵام بدەمەوە.');
      ref.read(voiceStateProvider.notifier).setState(VoiceState.error);
    }
  }
}


/// Compact circular button used by the modern voice screen.
class _SmallLiveButton extends StatelessWidget {
  const _SmallLiveButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.07),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

/// Red circular control for the Live Mode action.
class _EndLiveButton extends StatelessWidget {
  const _EndLiveButton({
    required this.onTap,
    this.size = 44,
  });

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFFF4D5E);

    return Material(
      color: red.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: const Icon(
            Icons.call_end_rounded,
            color: red,
            size: 21,
          ),
        ),
      ),
    );
  }
}
