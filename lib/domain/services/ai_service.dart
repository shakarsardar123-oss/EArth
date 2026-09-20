import '../entities/agent_config.dart';
import '../../core/ai/ai_message.dart';

/// Request model for AI completions.
class AIRequest {
  const AIRequest({
    required this.prompt,
    required this.agentConfig,
    this.conversationId,
    this.parentMessageId,
    this.temperature,
    this.maxTokens,
    this.stream = false,
    this.messages,
    this.toolDefinitions,
  });

  final String prompt;
  final AgentConfig agentConfig;
  final String? conversationId;
  final String? parentMessageId;
  final double? temperature;
  final int? maxTokens;
  final bool stream;

  /// Conversation history messages (for multi-turn and tool calls).
  final List<AIMessage>? messages;

  /// Tool definitions in OpenAI function-calling format.
  final List<Map<String, dynamic>>? toolDefinitions;
}

/// Response model for AI completions.
class AIResponse {
  AIResponse({
    required this.text,
    required this.modelId,
    this.conversationId,
    this.messageId,
    this.usage,
    this.finishReason,
    this.latencyMs,
  });

  final String text;
  final String modelId;
  final String? conversationId;
  final String? messageId;
  final AIUsage? usage;
  final String? finishReason;
  final int? latencyMs;

  /// Tool calls from the AI response (for agent engine).
  List<AIToolCall>? toolCalls;
}

/// Token usage metadata.
class AIUsage {
  const AIUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
  });

  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
}

/// Domain contract for AI text generation.
abstract class AIService {
  /// Sends a single [request] and returns the full [AIResponse].
  Future<AIResponse> complete(AIRequest request);

  /// Sends a [request] and returns a stream of partial responses.
  Stream<AIResponse> streamComplete(AIRequest request);
}
