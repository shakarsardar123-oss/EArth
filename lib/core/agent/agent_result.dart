import '../../core/errors/result.dart';
/// The final result of an agent execution cycle.
class AgentResult {
  const AgentResult.success({
    required this.response,
    this.stepsCompleted = 0,
    this.toolsUsed = const [],
    this.executionTimeMs = 0,
  })  : errorMessage = null,
        errorCode = null,
        isSuccess = true;

  const AgentResult.failure({
    required this.errorMessage,
    this.errorCode,
    this.stepsCompleted = 0,
    this.toolsUsed = const [],
    this.executionTimeMs = 0,
  })  : response = null,
        isSuccess = false;

  final String? response;
  final String? errorMessage;

  /// Optional stable, machine-readable error token (never localized, never a
  /// raw exception dump). Populated by [AgentEngine] when a failure maps to a
  /// known [AIErrorCategory] so the UI can present a friendly localized
  /// message. `null` for pre-existing failures that carry only a message.
  final String? errorCode;
  final bool isSuccess;
  final int stepsCompleted;
  final List<String> toolsUsed;
  final int executionTimeMs;

  @override
  String toString() {
    if (isSuccess) {
      return 'AgentResult.success(response: ${response?.substring(0, (response?.length ?? 0).clamp(0, 100))}, steps: $stepsCompleted, tools: $toolsUsed)';
    }
    return 'AgentResult.failure($errorMessage)';
  }
}
