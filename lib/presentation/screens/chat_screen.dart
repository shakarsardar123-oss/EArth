import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_assistant/l10n/app_localizations.dart';

import '../../core/providers/phase3_connection_points.dart';
import '../../services/voice/voice_service.dart' show VoiceState;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_adaptive.dart';
import '../../core/theme/app_spacing.dart';
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
import '../widgets/wireframe_background.dart';
import '../../core/errors/result.dart';
import '../../core/ai/ai_error_presenter.dart' show AIErrorPresenter;

class ChatMessagesNotifier extends ChangeNotifier {
  final List<_ChatMessage> _messages = [];
  List<_ChatMessage> get messages => List.unmodifiable(_messages);

  void addMessage(_ChatMessage msg) {
    _messages.add(msg);
    notifyListeners();
  }

  void removeLast() {
    if (_messages.isNotEmpty) {
      _messages.removeLast();
      notifyListeners();
    }
  }

  void clear() {
    _messages.clear();
    notifyListeners();
  }
}

/// Provider for current conversation ID
final currentConversationIdProvider = StateProvider<String?>((ref) => null);

/// Provider for chat messages list
final chatMessagesProvider = ChangeNotifierProvider((ref) => ChatMessagesNotifier());

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Chat Screen — cleaned up.
///
/// Changes from previous version:
///   • Back button navigates to index 0 (Home/VoiceScreen) instead of 3 (Dashboard)
///   • Dead attachment & camera buttons removed (empty onPressed)
///   • Non-functional info icon removed from header
///   • Background changed to AMOLED #000000 pure black
///   • All hardcoded strings replaced with l10n keys
///   • P0 Chat functionality FULLY PRESERVED
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  String? _loadedConversationId;
  bool _loadingConversation = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = ref.read(currentConversationIdProvider);
      if (id != null) {
        _loadConversation(id);
      }
    });
  }

  Future<void> _loadConversation(String? conversationId) async {
    if (!mounted) return;

    if (conversationId == null) {
      _loadedConversationId = null;
      ref.read(chatMessagesProvider).clear();
      return;
    }

    if (_loadedConversationId == conversationId || _loadingConversation) {
      return;
    }

    _loadingConversation = true;

    try {
      final memoryService = ref.read(memoryServiceProvider);
      final storedMessages =
          await memoryService.getMessages(conversationId);

      if (!mounted) return;

      final messages = ref.read(chatMessagesProvider);
      messages.clear();

      for (final message in storedMessages) {
        messages.addMessage(
          _ChatMessage(
            text: message.content,
            isUser: message.role == 'user',
            timestamp: message.createdAt ?? DateTime.now(),
          ),
        );
      }

      _loadedConversationId = conversationId;
      _scrollToBottom();
    } catch (e) {
      debugPrint(
        'Chat: failed to load conversation $conversationId: $e',
      );
    } finally {
      _loadingConversation = false;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Send typed text message
  Future<void> _sendMessage() async {
    final l10n = S.of(context);
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    final messages = ref.read(chatMessagesProvider);
    messages.addMessage(_ChatMessage(text: text, isUser: true));
    _scrollToBottom();

    try {
      // Create a persistent conversation automatically for a new chat.
      var convId = ref.read(currentConversationIdProvider);

      if (convId == null) {
        final memoryService = ref.read(memoryServiceProvider);

        convId = await memoryService.createConversation(
          title: text.length > 40 ? '${text.substring(0, 40)}…' : text,
          agentId: 'default',
        );

        // Mark it as loaded so the provider listener does not clear
        // the newly added local message while the conversation is loading.
        _loadedConversationId = convId;
        ref.read(currentConversationIdProvider.notifier).state = convId;
      }

      final agentEngine = ref.read(agentEngineProvider);
      final agentConfig = ref.read(agentConfigProvider);

      final history = messages.messages
          .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
          .toList();

      final context = AgentContext(
        agentConfig: agentConfig,
        conversationHistory: history,
        maxSteps: 10,
      );

      final result = await agentEngine.run(
        userInput: text,
        context: context,
      );

      if (result.isSuccess && result.response != null) {
        messages.addMessage(_ChatMessage(text: result.response!, isUser: false));

        // Persist both sides of the conversation to SQLite.
        try {
          final activeConvId = ref.read(currentConversationIdProvider);

          if (activeConvId != null) {
            final memoryService = ref.read(memoryServiceProvider);

            await memoryService.addMessage(
              conversationId: activeConvId,
              role: 'user',
              content: text,
            );

            await memoryService.addMessage(
              conversationId: activeConvId,
              role: 'assistant',
              content: result.response!,
            );

            ref.invalidate(conversationListFromDBProvider);
            ref.invalidate(conversationHistoryProvider);
          }
        } catch (e) {
          debugPrint('Chat: failed to persist message: $e');
        }
      } else {
        // Prefer the structured, localized category (via errorCode token)
        // over any raw/low-level message. Falls back to the engine's own
        // localized message, then a generic string.
        final failureText = result.errorCode != null
            ? AIErrorPresenter.present(result.errorCode, l10n)
            : (result.errorMessage ?? l10n.agentErrorGeneric);
        messages.addMessage(_ChatMessage(
          text: failureText,
          isUser: false,
        ));
      }
    } catch (e) {
      messages.addMessage(_ChatMessage(
        text: AIErrorPresenter.present(e, l10n),
        isUser: false,
      ));
    }

    _scrollToBottom();
  }

  /// Start a new conversation
  Future<void> _startNewConversation() async {
    final l10n = S.of(context);
    final messages = ref.read(chatMessagesProvider);
    messages.clear();
    _loadedConversationId = null;
    ref.read(currentConversationIdProvider.notifier).state = null;

    try {
      final memoryService = ref.read(memoryServiceProvider);
      final convId = await memoryService.createConversation(
        title: l10n.chatNewTitle,
        agentId: 'default',
      );
      ref.read(currentConversationIdProvider.notifier).state = convId;
    } catch (e) {
      debugPrint('Chat: failed to create conversation: $e');
    }
  }

  /// Retry last message
  Future<void> _retryLastMessage() async {
    final l10n = S.of(context);
    final messages = ref.read(chatMessagesProvider);
    final userMessages = messages.messages.where((m) => m.isUser).toList();
    if (userMessages.isEmpty) return;

    final lastUserMsg = userMessages.last.text;
    // Remove last AI response if exists
    if (messages.messages.isNotEmpty && !messages.messages.last.isUser) {
      messages.removeLast();
    }

    try {
      final agentEngine = ref.read(agentEngineProvider);
      final agentConfig = ref.read(agentConfigProvider);

      final history = messages.messages
          .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
          .toList();

      final context = AgentContext(
        agentConfig: agentConfig,
        conversationHistory: history,
        maxSteps: 10,
      );

      final result = await agentEngine.run(
        userInput: lastUserMsg,
        context: context,
      );

      if (result.isSuccess && result.response != null) {
        messages.addMessage(_ChatMessage(text: result.response!, isUser: false));
      } else {
        final failureText = result.errorCode != null
            ? AIErrorPresenter.present(result.errorCode, l10n)
            : (result.errorMessage ?? l10n.agentErrorGeneric);
        messages.addMessage(_ChatMessage(
          text: failureText,
          isUser: false,
        ));
      }
    } catch (e) {
      messages.addMessage(_ChatMessage(
        text: AIErrorPresenter.present(e, l10n),
        isUser: false,
      ));
    }

    _scrollToBottom();
  }

  /// Handle mic input
  Future<void> _handleMicInput() async {
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
        _controller.text = text;
        _sendMessage();
      },
      locale: 'ckb_IQ',
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(
      currentConversationIdProvider,
      (_, next) => _loadConversation(next),
    );

    final l10n = S.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final messages = ref.watch(chatMessagesProvider);
    final voiceState = ref.watch(voiceStateProvider);

    return Scaffold(
      backgroundColor: AppColors.amoledBlack, // AMOLED pure black
      body: SafeArea(
        child: Stack(
          children: [
            // ── Wireframe constellation overlay ──
            const Positioned.fill(
              child: WireframeBackground(
                opacity: 0.35,
                nodeCount: 15,
                lineDistance: 110,
              ),
            ),

            // ── Main content column ──
            Column(
              children: [
                // ── Header: back chevron + title ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      // Back chevron — navigates to Home (index 0)
                      IconButton(
                        icon: Icon(
                          Icons.chevron_left_rounded,
                          color: AppColors.onBackground.withValues(alpha: 0.7),
                          size: 28,
                        ),
                        onPressed: () {
                          ref.read(navigationIndexProvider.notifier).state = 0;
                        },
                      ),
                      Expanded(
                        child: Text(
                          l10n.chatNewTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onBackground,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Spacer to balance header (info icon removed — was non-functional)
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // ── Chat messages list ──
                Expanded(
                  child: messages.messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AuraOrb(
                                size: 100,
                                state: AuraOrbState.idle,
                                onTap: () {},
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.chatStartNew,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.hint,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          itemCount: messages.messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages.messages[index];
                            return _buildChatBubble(msg);
                          },
                        ),
                ),

                // ── Glass-morphic input bar ──
                _buildInputBar(context, voiceState),

                // Bottom padding for floating nav
                const SizedBox(height: 80),
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

  /// Chat bubble per reference: user = purple gradient frosted glass, AI = deeper translucent.
  Widget _buildChatBubble(_ChatMessage msg) {
    final isUser = msg.isUser;

    return Padding(
      // Directional insets so the 48px "breathing gap" mirrors correctly
      // under RTL (Kurdish) and LTR (English) without hardcoding sides.
      padding: EdgeInsetsDirectional.only(
        bottom: 8,
        start: isUser ? 48 : 0,
        end: isUser ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isUser ? 20 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 20),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                decoration: BoxDecoration(
                  gradient: isUser
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.chatBubbleUserGradientStart,
                            AppColors.chatBubbleUserGradientEnd,
                          ],
                        )
                      : null,
                  color: isUser
                      ? null
                      : AppColors.glassBackground.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 20 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 20),
                  ),
                  border: Border.all(
                    color: AppColors.glassBorder,
                    width: 0.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Text(
                  msg.text,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.onBackground,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Glass-morphic input bar — simplified: mic + text input + send button.
  /// Dead attachment & camera buttons removed (had empty onPressed handlers).
  Widget _buildInputBar(BuildContext context, VoiceState voiceState) {
    final l10n = S.of(context);
    final isListening = voiceState == VoiceState.listening;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glassInputBackground,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                // Mic icon
                if (isListening)
                  GestureDetector(
                    onTap: _handleMicInput,
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.magenta.withValues(alpha: 0.2),
                      ),
                      child: Icon(
                        Icons.mic_rounded,
                        color: AppColors.magenta,
                        size: 18,
                      ),
                    ),
                  ),

                if (!isListening)
                  IconButton(
                    icon: Icon(
                      Icons.mic_none_rounded,
                      color: AppColors.onBackground.withValues(alpha: 0.5),
                      size: 20,
                    ),
                    onPressed: _handleMicInput,
                  ),

                // Text input field
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.onBackground,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.chatTypeHint,
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: AppColors.hint.withValues(alpha: 0.6),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),

                // Magenta gradient send button
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 42,
                    height: 42,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.sendGradientStart,
                          AppColors.sendGradientEnd,
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}