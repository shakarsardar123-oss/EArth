/// Role types for AI messages following the OpenAI chat format.
enum AIMessageRole {
  system,
  user,
  assistant,
  tool;

  String toJson() => name;

  static AIMessageRole fromJson(String value) {
    return AIMessageRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => AIMessageRole.user,
    );
  }
}

/// Represents a single message in the AI conversation.
///
/// Supports the OpenAI chat completion format including tool calls
/// and tool call results.
class AIMessage {
  const AIMessage({
    required this.role,
    required this.content,
    this.toolCalls,
    this.toolCallId,
    this.name,
  this.metadata,
  });

  final AIMessageRole role;
  final String content;

  /// Tool calls requested by the assistant (null for non-assistant messages).
  final List<AIToolCall>? toolCalls;

  /// Tool call ID this message responds to (for tool role messages).
  final String? toolCallId;

  /// Name of the tool (for tool role messages).
  final String? name;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  /// Converts to the OpenAI chat message format.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'role': role.toJson(),
      'content': content,
    };
    if (toolCalls != null && toolCalls!.isNotEmpty) {
      map['tool_calls'] =
          toolCalls!.map((tc) => tc.toMap()).toList();
    }
    if (toolCallId != null) {
      map['tool_call_id'] = toolCallId;
    }
    if (name != null) {
      map['name'] = name;
    }
    return map;
  }

  /// Creates from a raw map (e.g. from API response or internal state).
  factory AIMessage.fromMap(Map<String, dynamic> map) {
    final toolCallsRaw = map['tool_calls'] as List<dynamic>?;
    return AIMessage(
      role: AIMessageRole.fromJson(map['role'] as String? ?? 'user'),
      content: map['content'] as String? ?? '',
      toolCalls: toolCallsRaw
          ?.map((tc) => AIToolCall.fromMap(tc as Map<String, dynamic>))
          .toList(),
      toolCallId: map['tool_call_id'] as String?,
      name: map['name'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() => 'AIMessage(role: $role, content: ${content.substring(0, content.length.clamp(0, 80))}...)';
}

/// Represents a single tool call from the assistant.
class AIToolCall {
  const AIToolCall({
    required this.id,
    required this.functionName,
    required this.arguments,
  });

  final String id;
  final String functionName;
  final Map<String, dynamic> arguments;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': 'function',
        'function': {
          'name': functionName,
          'arguments': arguments,
        },
      };

  factory AIToolCall.fromMap(Map<String, dynamic> map) {
    final function = map['function'] as Map<String, dynamic>?;
    return AIToolCall(
      id: map['id'] as String? ?? '',
      functionName: function?['name'] as String? ?? map['name'] as String? ?? '',
      arguments: function?['arguments'] as Map<String, dynamic>? ??
          map['arguments'] as Map<String, dynamic>? ?? {},
    );
  }
}
