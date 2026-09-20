import 'memory_service.dart';

/// Domain contract for memory/conversation persistence.
///
/// This repository coordinates between [MemoryService] and
/// higher-level use cases.
abstract class MemoryRepository {
  /// Creates a new conversation and returns its id.
  Future<String> createConversation({String? title, String? agentId});

  /// Retrieves conversation ids, most-recent first.
  Future<List<String>> getConversationIds({int limit = 50, int offset = 0});

  /// Adds a message to the given conversation.
  Future<void> addMessage({
    required String conversationId,
    required String role,
    required String content,
  });

  /// Retrieves messages for a conversation, ordered chronologically.
  Future<List<MessageEntity>> getMessages(String conversationId);

  /// Deletes a conversation and all its messages.
  Future<void> deleteConversation(String conversationId);
}
