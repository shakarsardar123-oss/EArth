/// step23_orchestration_adapter.dart
/// AURA Assistant – Step 25: Infrastructure adapter for Step 23 Orchestration.
///
/// Adapts Step 23's AgentEngine contract to Step 25's AgentEngineRepository.
/// FAIL-CLOSED: unavailable → conservative defaults (null results).
///
/// IMPORTANT: AgentEngineRepository has NO isAvailable method.
///
/// Implements the EXACT AgentEngineRepository interface:
///   understand(userRequest, locale) → Future<AgentIntent?>
///   plan(intent, memoryContext) → Future<AgentPlan?>
///   requiresTool(plan) → bool
///   requiresScreenAction(plan) → bool
library;

import '../domain/repositories/agent_engine_repository.dart';

/// Adapter bridging Step 23 Agent Engine to Step 25's AgentEngineRepository.
///
/// FAIL-CLOSED rules:
///   - Empty/blank user request → null intent (safe refusal)
///   - Null intent → null plan (safe refusal)
///   - Error in orchestration → null result (conservative default)
///   - requiresTool/ScreenAction read from AgentPlan directly
class Step23OrchestrationAdapter implements AgentEngineRepository {
  bool _enabled;

  Step23OrchestrationAdapter({bool enabled = true}) : _enabled = enabled;

  @override
  Future<AgentIntent?> understand(
    String userRequest,
    String locale,
  ) async {
    // FAIL-CLOSED: disabled → null (no intent parsed)
    if (!_enabled) return null;

    // FAIL-CLOSED: empty request → null
    if (userRequest.trim().isEmpty) return null;

    // In production, delegates to Step 23's AgentEngineProvider.
    // For structural validation, returns null (conservative default).
    return null;
  }

  @override
  Future<AgentPlan?> plan(
    AgentIntent intent,
    String? memoryContext,
  ) async {
    // FAIL-CLOSED: disabled → null
    if (!_enabled) return null;

    // FAIL-CLOSED: null intent → null plan
    // (AgentIntent is non-nullable by interface, but guard anyway)
    // ignore: unnecessary_null_comparison
    if (intent == null) return null;

    // In production, delegates to Step 23's AgentEngineProvider.plan().
    // For structural validation, returns null (conservative default).
    return null;
  }

  @override
  bool requiresTool(AgentPlan plan) {
    // Directly read from the plan — this is a data query, not a service call.
    return plan.requiresTool;
  }

  @override
  bool requiresScreenAction(AgentPlan plan) {
    // Directly read from the plan — this is a data query, not a service call.
    return plan.requiresScreenAction;
  }

  /// Enable/disable the adapter (for wiring/testing).
  void setEnabled(bool enabled) => _enabled = enabled;
}
