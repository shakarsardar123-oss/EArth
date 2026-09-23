import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_assistant/l10n/app_localizations.dart';

import '../../core/providers/phase3_connection_points.dart';
import 'chat_screen.dart' show currentConversationIdProvider;
import '../../services/voice/voice_service.dart' show VoiceState;
import '../../services/memory/memory_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/responsive.dart';
import '../../core/voice/voice_service_provider.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../../core/permissions/contextual_permission_helper.dart';
import '../../core/agent/agent_context.dart';
import '../../core/reaction/reaction.dart';
import '../../core/live_mode/live_mode_state.dart';
import '../../core/live_mode/live_mode_providers.dart'
    show liveModeOrchestratorProvider, liveModeStateProvider, isLiveSessionProvider;
import '../providers/app_providers.dart';
import '../widgets/glass_card.dart';
import '../widgets/aura_orb.dart';
import '../widgets/wireframe_background.dart';
import '../widgets/aura_reaction_banner.dart';
import '../../core/providers/greeting_provider.dart';
import '../../core/errors/result.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final layout = ResponsiveLayout.of(context);
    final agentName = ref.watch(agentNameProvider);
    final voiceState = ref.watch(voiceStateProvider);
    final conversations = ref.watch(conversationHistoryProvider);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // ── Background gradient ──
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background,
                    Color(0xFF0D0D1A),
                    AppColors.background,
                  ],
                ),
              ),
            ),

            // ── Wireframe constellation overlay ──
            const Positioned.fill(
              child: WireframeBackground(
                opacity: 0.6,
                nodeCount: 25,
                lineDistance: 120,
              ),
            ),

            // ── Content ──
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: layout.maxContentWidth,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.horizontalPadding,
                    vertical: 8,
                  ),
                  child: CustomScrollView(
                slivers: [
                  // ── Greeting: "Hi, [Name]" + subtitle ──
                  SliverToBoxAdapter(child: _buildGreeting(context, ref, agentName)),

                  // ── AURA Orb Centerpiece (standalone, not in GlassCard) ──
                  SliverToBoxAdapter(
                    child: _buildOrbCenterpiece(context, ref, voiceState),
                  ),

                  // ── 2x2 Glass Cards Grid ──
                  SliverToBoxAdapter(
                    child: _buildActionGrid(context, ref),
                  ),

                  // ── Live Mode status bar (when active) ──
                  SliverToBoxAdapter(
                    child: _buildLiveModeStatusBar(context, ref),
                  ),

                  // ── Recent Searches ──
                  SliverToBoxAdapter(
                    child: _buildRecentSearches(context, ref, conversations),
                  ),

                  // Bottom padding for floating nav bar
                  SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        ),

            // ── Reaction Banner overlay at top of screen ──
            const AuraReactionBanner(),
          ],
        ),
      ),
    );
  }

  /// Greeting matching reference: "Hi, [Name]" + subtitle.
  Widget _buildGreeting(BuildContext context, WidgetRef ref, String agentName) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final asyncGreeting = ref.watch(smartGreetingProvider);
    final greeting = resolveGreetingKey(asyncGreeting.whenData((g) => g).value ?? 'greetingSameDay');

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'بە هیوای ئەمڕۆت باش بێت؟',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.hint,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          // Profile icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.glassBackground,
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              color: AppColors.violetLight,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  /// Central AURA Orb — reflects Live Mode state when active.
  /// Standalone centerpiece (not wrapped in GlassCard) per reference.
  Widget _buildOrbCenterpiece(BuildContext context, WidgetRef ref, VoiceState voiceState) {
    final liveModeState = ref.watch(liveModeStateProvider);
    final isLive = ref.watch(isLiveSessionProvider);

    final orbState = isLive
        ? _liveModeStateToOrbState(liveModeState)
        : _voiceStateToOrbState(voiceState);

    final statusText = isLive
        ? 'دەنگی زیندوو: ${liveModeState.statusText}'
        : _getOrbStatusText(voiceState);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            AuraOrb(
              size: 180,
              state: orbState,
              onTap: isLive
                  ? () => _toggleLiveMode(context, ref)
                  : () => _handleMicTap(context, ref),
            ),
            const SizedBox(height: 16),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.violetLight,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 2x2 glass cards grid matching reference: New Chat, Chat with Image, Quick Tasks, Personalized Insights.
  Widget _buildActionGrid(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
        children: [
          // New Chat
          GlassCard(
            onTap: () {
              ref.read(navigationIndexProvider.notifier).state = 0; // Chat tab
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.violet.withValues(alpha: 0.15),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.violetLight,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'چاتی نوێ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onBackground,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'دەستپێکردنی گفتوگۆ',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.hint,
                  ),
                ),
              ],
            ),
          ),

          // Chat with Image
          GlassCard(
            onTap: () {
              ref.read(navigationIndexProvider.notifier).state = 2; // Vision tab
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.cyan.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.image_outlined,
                    color: AppColors.cyan,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'چات بە وێنە',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onBackground,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'ناردنی وێنە بۆ چات',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.hint,
                  ),
                ),
              ],
            ),
          ),

          // Quick Tasks
          GlassCard(
            onTap: () {
              ref.read(navigationIndexProvider.notifier).state = 0;
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.orange.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.bolt_outlined,
                    color: AppColors.orange,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'ئەرکە خێراکان',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onBackground,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'ئەرکی بەخێرایی',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.hint,
                  ),
                ),
              ],
            ),
          ),

          // Personalized Insights
          GlassCard(
            onTap: () {},
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.magenta.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.insights_outlined,
                    color: AppColors.magenta,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'بینینی تایبەت',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onBackground,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'ڕاوێژی تایبەتمەند',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.hint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Live Mode status bar (when active).
  Widget _buildLiveModeStatusBar(BuildContext context, WidgetRef ref) {
    final liveModeState = ref.watch(liveModeStateProvider);
    final isLive = ref.watch(isLiveSessionProvider);

    if (!isLive) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        showGlow: true,
        glowColor: AppColors.violet,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: liveModeState == LiveModeState.error
                    ? AppColors.error
                    : AppColors.violetLight,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'دەنگی زیندوو: ${liveModeState.statusText}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.violetLight,
              ),
            ),
            Spacer(),
            GestureDetector(
              onTap: () => _toggleLiveMode(context, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'وەستان',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Recent Searches section matching reference: title + "See all" link + items.
  Widget _buildRecentSearches(BuildContext context, WidgetRef ref, List<ConversationItem> conversations) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with "See all"
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'گەڕانەکانی پێشوو',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onBackground,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // Open conversation history in the Chat tab
                    ref.read(navigationIndexProvider.notifier).state = 1;
                  },
                  child: Text(
                    'هەمووی ببینە',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.violetLight,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Conversation items
          if (conversations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'هیچ گفتوگۆیەکی پێشوو نییە',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.hint,
                  ),
                ),
              ),
            )
          else
            ...conversations.take(3).map((item) => GlassCard(
              margin: const EdgeInsets.only(bottom: 8),
              onTap: () {
                ref.read(currentConversationIdProvider.notifier).state = item.id;
                ref.read(navigationIndexProvider.notifier).state = 1;
              },
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.violet.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: AppColors.violetLight,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.onBackground,
                          ),
                        ),
                        Text(
                          item.subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.hint,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.hint,
                    size: 18,
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  /// Map LiveModeState to AuraOrbState.
  AuraOrbState _liveModeStateToOrbState(LiveModeState state) => switch (state) {
    LiveModeState.listening => AuraOrbState.listening,
    LiveModeState.processing => AuraOrbState.thinking,
    LiveModeState.speaking => AuraOrbState.speaking,
    LiveModeState.error => AuraOrbState.error,
    _ => AuraOrbState.idle,
  };

  AuraOrbState _voiceStateToOrbState(VoiceState voiceState) {
    switch (voiceState) {
      case VoiceState.listening:
        return AuraOrbState.listening;
      case VoiceState.processing:
        return AuraOrbState.thinking;
      case VoiceState.speaking:
        return AuraOrbState.speaking;
      case VoiceState.error:
        return AuraOrbState.error;
      default:
        return AuraOrbState.idle;
    }
  }

  String _getOrbStatusText(VoiceState voiceState) {
    switch (voiceState) {
      case VoiceState.listening:
        return 'گوێگرتن...';
      case VoiceState.processing:
        return 'بیرکردنەوە...';
      case VoiceState.speaking:
        return 'قسەکردن...';
      case VoiceState.error:
        return 'هەڵە';
      default:
        return 'بۆ قسەکردن داوا بکە';
    }
  }

  /// Toggle Live Mode on/off from dashboard.
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

    final session = await orchestrator.startSession();
    if (session == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('نەمدتوانم دەنگی زیندوو دەست پێ بکەم'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Real mic tap handler.
  Future<void> _handleMicTap(BuildContext context, WidgetRef ref) async {
    final voiceState = ref.read(voiceStateProvider);

    if (voiceState == VoiceState.speaking || voiceState == VoiceState.processing) {
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

  /// Send recognized text to AgentEngine and speak the response.
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
        ref.read(aiResponseProvider.notifier).update((_) => result.response!);

        final voiceService = ref.read(voiceServiceImplProvider);
        final coordinator = ref.read(reactionSpeechCoordinatorProvider);
        await coordinator.speakOrHold(
          result.response!,
          (text) => voiceService.speak(text),
        );

        try {
          final memoryService = ref.read(memoryServiceProvider);
          final convId = await memoryService.createConversation(
            title: userInput.length > 40
                ? '${userInput.substring(0, 40)}...'
                : userInput,
            agentId: 'default',
          );
          await memoryService.addMessage(
            conversationId: convId,
            role: 'user',
            content: userInput,
          );
          await memoryService.addMessage(
            conversationId: convId,
            role: 'assistant',
            content: result.response!,
          );
          ref.invalidate(conversationListFromDBProvider);
        } catch (e) {
          debugPrint('Dashboard: failed to persist voice conversation: $e');
        }
      } else {
        ref.read(aiResponseProvider.notifier).update((_) =>
            result.errorMessage ?? 'ببورە، هەڵەیەک ڕوویدا.');
        ref.read(voiceStateProvider.notifier).setState(VoiceState.error);
      }
    } catch (e) {
      ref.read(aiResponseProvider.notifier).update((_) => 'ببورە، نەمتوانم وەڵام بدەمەوە.');
      ref.read(voiceStateProvider.notifier).setState(VoiceState.error);
    }
  }
}