import '../../domain/services/ai_service.dart';
import '../../core/ai/ai_message.dart';
import '../../core/agent/agent_context.dart';
import '../../services/ai/ai_provider.dart';

/// Adapter that bridges [AgentEngine.sendToAI] to [OpenAIProvider.complete].
///
/// Converts the raw Map-based messages and tool definitions used by
/// AgentEngine into typed [AIRequest]/[AIResponse] objects, then calls
/// [AIProvider.complete] and converts the result back to a Map.
Future<Map<String, dynamic>> sendToAIAdapter({
  required List<Map<String, dynamic>> messages,
  required List<Map<String, dynamic>> toolDefinitions,
  required AgentContext context,
  required AIProvider aiProvider,
}) async {
  // Convert raw message maps to AIMessage objects.
  final aiMessages = messages
      .map((m) => AIMessage.fromMap(m))
      .toList();

  // Extract the last user message as the prompt.
  final lastUserMessage = messages.lastWhere(
    (m) => m['role'] == 'user',
    orElse: () => {'content': ''},
  )['content'] as String? ?? '';

  // Build the AIRequest.
  final request = AIRequest(
    prompt: lastUserMessage,
    agentConfig: context.agentConfig,
    messages: aiMessages,
    toolDefinitions: toolDefinitions.isNotEmpty ? toolDefinitions : null,
    temperature: context.agentConfig.temperature,
    maxTokens: context.agentConfig.maxTokens,
  );

  // Call the AI provider.
  final response = await aiProvider.complete(request);

  // Convert AIResponse back to Map<String, dynamic> for AgentEngine.
  return {
    'content': response.text,
    'tool_calls': response.toolCalls?.map((tc) => tc.toMap()).toList(),
  };
}
