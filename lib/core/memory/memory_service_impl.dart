import '../utils/uuid_util.dart';

import '../../services/memory/memory_service.dart';
import '../../core/memory/memory_database.dart';

/// Real [MemoryService] implementation backed by sqflite.
class MemoryServiceImpl implements MemoryService {
  MemoryServiceImpl({required MemoryDatabase database}) : _db = database;

  final MemoryDatabase _db;
  final _uuid = UuidUtil();

  @override
  Future<String> createConversation({String? title, String? agentId}) async {
    final db = await _db.database;
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert('conversations', {
      'id': id,
      'agent_id': agentId ?? 'default',
      'title': title,
      'created_at': now,
      'updated_at': now,
    });

    return id;
  }

  @override
  Future<List<String>> getConversationIds({int limit = 50, int offset = 0}) async {
    final db = await _db.database;
    final rows = await db.query(
      'conversations',
      columns: ['id'],
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );

    return rows.map((r) => r['id'] as String).toList();
  }

  @override
  Future<void> addMessage({
    required String conversationId,
    required String role,
    required String content,
    String? parentMessageId,
  }) async {
    final db = await _db.database;
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert('messages', {
      'id': id,
      'conversation_id': conversationId,
      'role': role,
      'content': content,
      'parent_message_id': parentMessageId,
      'created_at': now,
    });

    // Update conversation's updated_at timestamp.
    await db.update(
      'conversations',
      {'updated_at': now},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  @override
  Future<List<MessageEntity>> getMessages(String conversationId) async {
    final db = await _db.database;
    final rows = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );

    return rows.map((r) => MessageEntity(
      id: r['id'] as String,
      conversationId: r['conversation_id'] as String,
      role: r['role'] as String,
      content: r['content'] as String,
      parentMessageId: r['parent_message_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
    )).toList();
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    final db = await _db.database;
    // SQLite ON DELETE CASCADE handles messages automatically
    // if foreign_keys is enabled. For safety, delete manually too.
    await db.delete(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
    await db.delete(
      'conversations',
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }
}
