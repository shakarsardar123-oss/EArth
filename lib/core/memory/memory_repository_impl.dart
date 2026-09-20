import '../../services/memory/memory_service.dart';
import '../../core/memory/memory_database.dart';
import '../../core/memory/memory_service_impl.dart';

/// Repository implementation for conversation persistence.
/// Provides higher-level access to the memory subsystem.
class MemoryRepositoryImpl {
  MemoryRepositoryImpl({required MemoryDatabase database})
      : _memoryService = MemoryServiceImpl(database: database);

  final MemoryService _memoryService;
  /// Creates a new conversation and returns its entity.
  Future<ConversationEntity> createConversation({
    String? title,
    String? agentId,
  }) async {
    final id = await _memoryService.createConversation(
      title: title,
      agentId: agentId,
    );
    return ConversationEntity(
      id: id,
      agentId: agentId ?? 'default',
      title: title,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Gets conversation entities (not just IDs).
  Future<List<ConversationEntity>> getConversations({
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await MemoryDatabase().database;
    final rows = await db.query(
      'conversations',
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );

    return rows.map((r) => ConversationEntity(
      id: r['id'] as String,
      agentId: r['agent_id'] as String,
      title: r['title'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
    )).toList();
  }

  /// Gets the underlying memory service for direct access.
  MemoryService get memoryService => _memoryService;
}
