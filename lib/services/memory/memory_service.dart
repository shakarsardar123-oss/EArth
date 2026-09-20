/// Abstraction for the memory/conversation persistence subsystem.
///
/// Phase 2+ will implement local + cloud memory. Phase 1 defines
/// the contract.
abstract class MemoryService {
  /// Creates a new conversation and returns its id.
  Future<String> createConversation({String? title, String? agentId});

  /// Retrieves conversation ids, most-recent first.
  Future<List<String>> getConversationIds({int limit = 50, int offset = 0});

  /// Adds a message to the given conversation.
  Future<void> addMessage({
    required String conversationId,
    required String role,
    required String content,
    String? parentMessageId,
  });

  /// Retrieves messages for a conversation, ordered chronologically.
  Future<List<MessageEntity>> getMessages(String conversationId);

  /// Deletes a conversation and all its messages.
  Future<void> deleteConversation(String conversationId);
}

/// Lightweight entity for a stored message.
class MessageEntity {
  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.parentMessageId,
    this.createdAt,
  });

  final String id;
  final String conversationId;
  final String role; // 'user', 'assistant', 'system'
  final String content;
  final String? parentMessageId;
  final DateTime? createdAt;
}

/// Lightweight entity for a conversation.
class ConversationEntity {
  const ConversationEntity({
    required this.id,
    required this.agentId,
    this.title,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String agentId;
  final String? title;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
