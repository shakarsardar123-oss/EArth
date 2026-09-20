/// Step 23 — Agent Engine Repository Interface
///
/// Contract for the Step 16 AgentEngine adapter.
/// The orchestrator never calls AgentEngine directly — it goes through this interface.

abstract class AgentEngineRepository {
  /// Understand the user request and produce a structured intent.
  /// Returns null if understanding fails (FAIL-CLOSED → denied).
  Future<AgentIntent?> understand(String userRequest, String locale);

  /// Plan actions based on the intent and optional memory context.
  /// Returns null if planning fails (FAIL-CLOSED → denied).
  Future<AgentPlan?> plan(AgentIntent intent, String? memoryContext);

  /// Determine if the plan requires a tool execution.
  bool requiresTool(AgentPlan plan);

  /// Determine if the plan requires a screen/device action.
  bool requiresScreenAction(AgentPlan plan);
}

/// Lightweight intent representation produced by understanding.
class AgentIntent {
  final String intentId;
  final String rawText;
  final String normalizedText;
  final String locale;
  final bool isToolAction;
  final bool isScreenAction;
  final bool isDirectResponse;

  const AgentIntent({
    required this.intentId,
    required this.rawText,
    required this.normalizedText,
    required this.locale,
    this.isToolAction = false,
    this.isScreenAction = false,
    this.isDirectResponse = false,
  });
}

/// Lightweight plan representation.
class AgentPlan {
  final String planId;
  final String intentId;
  final bool needsMemory;
  final bool needsTool;
  final bool needsScreenAction;
  final bool isDirectResponse;
  final String? suggestedToolCategory;
  final String? suggestedResponse;

  const AgentPlan({
    required this.planId,
    required this.intentId,
    this.needsMemory = false,
    this.needsTool = false,
    this.needsScreenAction = false,
    this.isDirectResponse = false,
    this.suggestedToolCategory,
    this.suggestedResponse,
  });
}
