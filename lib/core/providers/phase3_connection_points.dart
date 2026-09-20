import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/voice/voice_service.dart' show VoiceState;
import '../../core/voice/voice_service_provider.dart' show voiceServiceImplProvider;
import '../../presentation/providers/app_providers.dart'
    show connectionStatusStreamProvider, memoryRepositoryProvider;
import '../../services/memory/memory_service.dart' show ConversationEntity;

/// Phase 3 connection point providers.
///
/// These providers wire the real Phase 3 implementations to the UI.
/// VoiceState is imported from the canonical definition in
/// lib/services/voice/voice_service.dart (5 states with isActive).

/// Notifier that tracks the real voice state from VoiceServiceImpl.
class VoiceStateNotifier extends StateNotifier<VoiceState> {
  VoiceStateNotifier(this._voiceServiceImpl) : super(VoiceState.idle) {
    _init();
  }

  final dynamic _voiceServiceImpl;
  StreamSubscription<VoiceState>? _subscription;

  void _init() {
    // Listen to the state stream from VoiceServiceImpl
    final stream = _voiceServiceImpl.stateStream;
    if (stream != null) {
      _subscription = stream.listen((state) {
        this.state = state;
      });
    }
  }

  /// Manually set the state (e.g., from UI reset).
  void setState(VoiceState newState) {
    state = newState;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Real voice state provider — delegates to VoiceServiceImpl via notifier.
final voiceStateProvider = StateNotifierProvider<VoiceStateNotifier, VoiceState>((ref) {
  final voiceService = ref.watch(voiceServiceImplProvider);
  return VoiceStateNotifier(voiceService);
});

/// Voice transcript provider — updated by VoiceService recognition results.
final voiceTranscriptProvider = StateProvider<String>((ref) => '');

/// AI response provider — updated by AgentEngine after AI processing.
final aiResponseProvider = StateProvider<String>((ref) => '');

/// Connection status — delegates to connectionStatusStreamProvider.
/// Uses the latest value from the connectivity stream.
final connectionStatusProvider = StateProvider<bool>((ref) {
  final asyncValue = ref.watch(connectionStatusStreamProvider);
  return asyncValue.maybeWhen(
    data: (isConnected) => isConnected,
    orElse: () => true,
  );
});

/// Agent name provider — reads from app config.
/// Default is 'AURA' (the app name).
final agentNameProvider = StateProvider<String>((ref) => 'AURA');

/// Conversation history — persisted via MemoryService.
class ConversationItem {
  const ConversationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });
  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
}

/// FutureProvider that loads conversation list from DB.
/// Invalidated by ChatScreen when new conversations are created.
final conversationListFromDBProvider = FutureProvider<List<ConversationItem>>((ref) async {
  final repo = ref.watch(memoryRepositoryProvider);
  final conversations = await repo.getConversations(limit: 20);

  // Load first message of each conversation for subtitle
  final memoryService = repo.memoryService;
  final items = <ConversationItem>[];

  for (final c in conversations) {
    String subtitle = c.agentId;
    try {
      final msgs = await memoryService.getMessages(c.id);
      if (msgs.isNotEmpty) {
        // Use the first user message as subtitle
        final firstUserMsg = msgs.firstWhere(
          (m) => m.role == 'user',
          orElse: () => msgs.first,
        );
        subtitle = firstUserMsg.content.length > 50
            ? '${firstUserMsg.content.substring(0, 50)}...'
            : firstUserMsg.content;
      }
    } catch (_) {
      // Keep default subtitle
    }

    items.add(ConversationItem(
      id: c.id,
      title: c.title ?? 'بەبێ ناونیشان',
      subtitle: subtitle,
      timestamp: c.updatedAt ?? c.createdAt ?? DateTime.now(),
    ));
  }

  return items;
});

/// Conversation history provider — backed by DB.
/// Watches the FutureProvider and converts to synchronous state for UI.
final conversationHistoryProvider = StateProvider<List<ConversationItem>>((ref) {
  final asyncValue = ref.watch(conversationListFromDBProvider);
  return asyncValue.maybeWhen(
    data: (items) => items,
    orElse: () => [],
  );
});

/// Navigation tab index provider for the main shell.
final navigationIndexProvider = StateProvider<int>((ref) => 0);