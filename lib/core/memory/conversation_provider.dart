import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/phase3_connection_points.dart';
import '../../core/memory/memory_database.dart';
import '../../core/memory/memory_repository_impl.dart';
import '../../services/memory/memory_service.dart';

/// Provider for the MemoryDatabase instance.
final memoryDatabaseProvider = Provider<MemoryDatabase>((ref) {
  return MemoryDatabase();
});

/// Provider for the MemoryRepositoryImpl.
final memoryRepositoryProvider = Provider<MemoryRepositoryImpl>((ref) {
  return MemoryRepositoryImpl(
    database: ref.watch(memoryDatabaseProvider),
  );
});

/// Provider for the MemoryService.
final memoryServiceProvider = Provider<MemoryService>((ref) {
  return ref.watch(memoryRepositoryProvider).memoryService;
});

/// Async provider that loads conversation history as [ConversationItem]s.
final conversationListProvider = FutureProvider<List<ConversationItem>>((ref) async {
  final repo = ref.watch(memoryRepositoryProvider);
  final conversations = await repo.getConversations(limit: 20);

  return conversations.map((c) => ConversationItem(
    id: c.id,
    title: c.title ?? 'بەبێ ناونیشان',
    subtitle: c.agentId,
    timestamp: c.updatedAt ?? DateTime.now(),
  )).toList();
});
