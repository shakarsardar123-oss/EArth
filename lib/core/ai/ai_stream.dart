/// Represents a chunk of a streaming AI response.
class AIStreamChunk {
  const AIStreamChunk({
    required this.delta,
    this.toolCallDelta,
    this.finishReason,
    this.usage,
  });

  /// The text content of this chunk.
  final String delta;

  /// Partial tool call data (for streaming tool calls).
  final AIToolCallDelta? toolCallDelta;

  /// Finish reason: 'stop', 'tool_calls', 'length', etc.
  final String? finishReason;

  /// Token usage (only in the final chunk).
  final AIStreamUsage? usage;

  @override
  String toString() => 'AIStreamChunk(delta: "$delta", finish: $finishReason)';
}

/// Partial tool call data in a streaming chunk.
class AIToolCallDelta {
  const AIToolCallDelta({
    this.index,
    this.id,
    this.functionName,
    this.argumentsDelta,
  });

  final int? index;
  final String? id;
  final String? functionName;
  final String? argumentsDelta;
}

/// Token usage from a streaming response final chunk.
class AIStreamUsage {
  const AIStreamUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
  });

  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
}
