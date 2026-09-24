/// Step 23 — Agent Engine Adapter
///
/// Thin adapter bridging Step 23 AgentEngineRepository to existing Step 16 AgentEngine.
/// Does NOT duplicate AgentEngine functionality — only translates interfaces.
/// If the actual AgentEngine API differs, this adapter normalizes it.
///
/// ── CLASSIFICATION: CLASS C (BLOCKED — API SHAPE MISMATCH) ──────────────
/// The canonical Step 16 [AgentEngine] does NOT expose discrete
/// `understand()` / `plan()` methods. Both are PRIVATE (`_understand`,
/// `_planner.plan`) and are fused inside the single public entry point
/// `AgentEngine.run({userInput, context})`, which drives the entire
/// understand→plan→execute→verify lifecycle in one call and returns an
/// `AgentResult` (not an `AgentIntent` / `AgentPlan`).
///
/// The orchestration `AgentEngineRepository` contract, by contrast, needs
/// the understand and plan phases as SEPARATE, side-effect-free steps so
/// the orchestrator can interleave its own memory / security / permission
/// phases between them. There is currently no public seam on AgentEngine
/// to obtain a standalone intent or plan without also executing the plan.
///
/// BLOCKED: wiring the real engine requires either (a) exposing
/// `understand()` and `plan()` as public methods on AgentEngine, or
/// (b) refactoring AgentPlanner into an independently-invokable service.
/// Until then this adapter returns structurally-valid placeholder
/// AgentIntent / AgentPlan objects (FAIL-CLOSED to null on any error),
/// which keeps the orchestration graph complete and swappable.
/// This adapter creates NO second planning engine.
/// ───────────────────────────────────────────────────────────────────────

import '../../domain/repositories/agent_engine_repository.dart';

class AgentEngineAdapter implements AgentEngineRepository {
  @override
  Future<AgentIntent?> understand(String userRequest, String locale) async {
    // Adapter: call Step 16 AgentEngine.understand() and normalize result.
    // In production, this calls the real AgentEngine.
    // For structural validation: returns null on any failure (FAIL-CLOSED).
    try {
      // BLOCKED: AgentEngine exposes no public understand() seam (only the
      // private _understand inside run()). Returning a structural intent.
      // TODO: Wire to actual Step 16 AgentEngine.understand()
      // AgentIntent is constructed from the Step 16 result
      return AgentIntent(
        intentId: 'intent_${DateTime.now().millisecondsSinceEpoch}',
        rawText: userRequest,
        normalizedText: userRequest,
        locale: locale,
      );
    } catch (_) {
      return null; // FAIL-CLOSED
    }
  }

  @override
  Future<AgentPlan?> plan(AgentIntent intent, String? memoryContext) async {
    try {
      // BLOCKED: AgentEngine exposes no public plan() seam (planning is
      // fused into run() via the private AgentPlanner). Structural plan only.
      // TODO: Wire to actual Step 16 AgentEngine.plan()
      return AgentPlan(
        planId: 'plan_${DateTime.now().millisecondsSinceEpoch}',
        intentId: intent.intentId,
        needsMemory: memoryContext == null,
        needsTool: intent.isToolAction,
        needsScreenAction: intent.isScreenAction,
        isDirectResponse: intent.isDirectResponse,
      );
    } catch (_) {
      return null; // FAIL-CLOSED
    }
  }

  @override
  bool requiresTool(AgentPlan plan) => plan.needsTool;

  @override
  bool requiresScreenAction(AgentPlan plan) => plan.needsScreenAction;
}
