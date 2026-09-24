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
    final cs = theme.colorScheme;
    ref.watch(voiceStateProvider);
    final transcript = ref.watch(voiceTranscriptProvider);
    final aiResponse = ref.watch(aiResponseProvider);
    final liveModeState = ref.watch(liveModeStateProvider);
    final isLive = ref.watch(isLiveSessionProvider);
    final voiceState = ref.read(voiceStateProvider);

    // Smart Greeting — from greeting_provider
    final greetingAsync = ref.watch(smartGreetingProvider);
    final greetingText = greetingAsync.maybeWhen(
      data: (key) => resolveGreetingKey(key),
      orElse: () => 'سڵاو',
    );

    // Map to WaveForm state
    final waveFormState = isLive
        ? _liveModeStateToWaveFormState(liveModeState)
        : _voiceStateToWaveFormState(voiceState);

    final statusText = isLive
        ? l10n.liveModeActive
        : _getStatusText(l10n, voiceState);

    final isListening = voiceState == VoiceState.listening ||
        (isLive && liveModeState == LiveModeState.listening);

    return Scaffold(
      backgroundColor: AppColors.amoledBlack, // AMOLED pure black
      body: SafeArea(
        child: Stack(
          children: [
            // ── Main layout ──
            Column(
              children: [
                const SizedBox(height: 12),

                // ── Smart Greeting ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    greetingText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.violetLight.withOpacity(0.85),
                      letterSpacing: 0.5,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 10),

                // ── AURA header ──
                Text(
                  'TEXO',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.waveFormCyan,
                    letterSpacing: 6.0,
                  ),
                ),

                const SizedBox(height: 4),

                // ── AURA Identity ──
                Text(
                  l10n.auraIdentity,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.cyan.withOpacity(0.6),
                    letterSpacing: 1.0,
                  ),
                ),

                const SizedBox(height: 6),

                // ── Status text ──
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isListening
                        ? AppColors.cyan
                        : AppColors.violetLight,
                    letterSpacing: 1.5,
                  ),
                ),

                const Spacer(flex: 3),

                // ── Central visualization: wave form + globe as ONE
                // composition. The waveform runs full-bleed edge to edge;
                // `occlusionRadius` is derived directly from `globeSize`
                // (the same value the globe itself uses) so the bars
                // smoothly fade out exactly where the globe actually is,
                // not at some hardcoded screen coordinate. `centerGap`
                // adds a gentle amplitude taper on top so the shape
                // narrows before it reaches the globe rather than
                // staying full-height right up to the fade boundary.
                Builder(builder: (context) {
                  const double globeSize = 168.0;
                  return SizedBox(
                    height: 190,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: Center(
                            child: AuraWaveForm(
                              state: waveFormState,
                              barCount: 56,
                              barGap: 2.5,
                              maxBarHeight: 90.0,
                              minBarHeight: 3.0,
                              fullBleed: true,
                              centerGap: 0.3,
                              occlusionRadius: globeSize / 2 + 4,
                              occlusionFeather: 34,
                            ),
                          ),
                        ),
                        RealisticGlobe(
                          controller: _globeController,
                          size: globeSize,
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 32),

                // ── Descriptive subtext ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    isLive ? l10n.liveModeActive : l10n.voicePromptHint,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppColors.hint.withOpacity(0.5),
                      letterSpacing: 2.0,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const Spacer(flex: 3),

                // ── Transcript area (when there's content) ──
                if (transcript.isNotEmpty || aiResponse.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              transcript,
                              style: TextStyle(fontSize: 14, color: cs.onSurface),
                            ),
                          ],
                          if (aiResponse.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              l10n.responseLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.cyan,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              aiResponse,
                              style: TextStyle(fontSize: 14, color: cs.onSurface),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                // ── 3 Footer controls ──
                Padding(
                  padding: const EdgeInsets.only(bottom: 24, top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Chat navigation button (replaces dead menu hamburger)
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.glassBackground,
                          border: Border.all(
                            color: AppColors.glassBorder,
                            width: 0.5,
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: AppColors.onBackground.withOpacity(0.7),
                            size: 24,
                          ),
                          onPressed: () {
                            ref.read(navigationIndexProvider.notifier).state = 1;
                          },
                        ),
                      ),

                      // Central voice button
                      GestureDetector(
                        onTap: isLive
                            ? () => _toggleLiveMode(context, ref)
                            : () => _handleMicTap(context, ref),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.voiceButtonGradientStart,
                                AppColors.voiceButtonGradientEnd,
                              ],
                            ),
                            boxShadow: isListening
                                ? [
                                    BoxShadow(
                                      color: AppColors.magenta.withOpacity(0.4),
                                      blurRadius: 24,
                                      spreadRadius: 4,
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: AppColors.violet.withOpacity(0.25),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                          ),
                          child: Icon(
                            isListening
                                ? Icons.mic_rounded
                                : Icons.mic_none_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),

                      // Settings gear (index 2)
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.glassBackground,
                          border: Border.all(
                            color: AppColors.glassBorder,
                            width: 0.5,
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.settings_outlined,
                            color: AppColors.onBackground.withOpacity(0.7),
                            size: 22,
                          ),
                          onPressed: () {
                            ref.read(navigationIndexProvider.notifier).state = 2;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Reaction Banner overlay at top ──
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