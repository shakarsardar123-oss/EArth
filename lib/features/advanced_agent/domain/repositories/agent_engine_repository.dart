/// agent_engine_repository.dart
/// AURA Assistant – Step 25: Adapter target for Step 23 AgentEngineRepository
///
/// Exact signature match from Step 23.
/// This interface MUST be implemented by Step23OrchestrationAdapter.
library;

/// Represents an agent intent parsed from a user request.
class AgentIntent {
  final String intentId;
  final String action;
  final Map<String, dynamic> parameters;
  final double confidence;

  const AgentIntent({
    required this.intentId,
    required this.action,
    this.parameters = const {},
    this.confidence = 0.0,
  });

  @override
  String toString() => 'AgentIntent(id: $intentId, action: $action, conf: $confidence)';
}

/// Represents an agent plan for executing an intent.
class AgentPlan {
  final String planId;
  final String intentId;
  final List<Map<String, dynamic>> steps;
  final bool requiresTool;
  final bool requiresScreenAction;

  const AgentPlan({
    required this.planId,
    required this.intentId,
    this.steps = const [],
    this.requiresTool = false,
    this.requiresScreenAction = false,
  });

  @override
  String toString() => 'AgentPlan(id: $planId, intent: $intentId, tools: $requiresTool)';
}

/// Abstract repository matching Step 23's AgentEngineRepository.
/// understand(userRequest, locale) → AgentIntent?
/// plan(intent, memoryContext) → AgentPlan?
/// requiresTool(plan) → bool
/// requiresScreenAction(plan) → bool
abstract class AgentEngineRepository {
  Future<AgentIntent?> understand(String userRequest, String locale);
  Future<AgentPlan?> plan(AgentIntent intent, String? memoryContext);
  bool requiresTool(AgentPlan plan);
  bool requiresScreenAction(AgentPlan plan);
}
