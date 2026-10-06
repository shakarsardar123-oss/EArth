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
  void Function(String text)? onTextChunk,
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
    stream: true,
  );

  final buffer = StringBuffer();
  final toolCalls = <Map<String, dynamic>>[];

  await for (final response in aiProvider.streamComplete(request)) {
    if (response.text.isNotEmpty) {
      buffer.write(response.text);
      onTextChunk?.call(response.text);
    }

    final responseToolCalls = response.toolCalls;
    if (responseToolCalls != null && responseToolCalls.isNotEmpty) {
      for (final toolCall in responseToolCalls) {
        toolCalls.add(toolCall.toMap());
      }
    }
  }

  return {
    'content': buffer.toString(),
    'tool_calls': toolCalls.isEmpty ? null : toolCalls,
  };
}

/// Streams text responses from the selected AI provider.
///
/// This is kept separate from [sendToAIAdapter] so the existing
/// tool/agent completion path remains backward-compatible.
