/// Step 23 — Agent Engine Adapter
///
/// Bridges the Step 23 AgentEngineRepository contract to the canonical
/// Step 16 AgentEngine.
///
/// IMPORTANT:
/// - Uses the existing AgentEngine instance.
/// - Does NOT call AgentEngine.run().
/// - Does NOT create a second planning engine.
/// - Exposes only the understand/plan seams needed by Step 23.
/// - Converts between the lightweight Step 23 DTOs and canonical core models.

import '../../../../core/agent/agent_context.dart';
import '../../../../core/agent/agent_engine.dart';
import '../../../../core/agent/agent_intent.dart' as core;
import '../../../../core/agent/agent_plan.dart' as core;
import '../../../../domain/entities/agent_config.dart';

import '../../domain/repositories/agent_engine_repository.dart'
    as orchestration;

class AgentEngineAdapter implements orchestration.AgentEngineRepository {
  final AgentEngine _agentEngine;

  AgentEngineAdapter({
    required AgentEngine agentEngine,
  }) : _agentEngine = agentEngine;

  @override
  Future<orchestration.AgentIntent?> understand(
    String userRequest,
    String locale,
  ) async {
    try {
      final context = AgentContext(
        agentConfig: AgentConfig.defaultConfig,
        conversationHistory: [
          {
            'role': 'user',
            'content': userRequest,
          },
        ],
        maxSteps: 10,
        timeoutSeconds: 120,
        currentGoal: userRequest,
      );

      final intent = await _agentEngine.understandForOrchestration(
        userInput: userRequest,
        context: context,
      );

      return orchestration.AgentIntent(
        intentId: 'intent_${DateTime.now().microsecondsSinceEpoch}',
        rawText: userRequest,
        normalizedText: intent.goal,
        locale: locale,
        isToolAction: intent.actionType.requiresTools,
        isScreenAction: _isScreenAction(intent),
        isDirectResponse:
            intent.actionType == core.IntentActionType.conversation,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<orchestration.AgentPlan?> plan(
    orchestration.AgentIntent intent,
    String? memoryContext,
  ) async {
    try {
      final coreIntent = core.AgentIntent(
        goal: intent.normalizedText.isNotEmpty
            ? intent.normalizedText
            : intent.rawText,
        actionType: _toCoreActionType(intent),
        originalUtterance: intent.rawText,
        confidence: intent.isDirectResponse ? 1.0 : 0.8,
      );

      final context = AgentContext(
        agentConfig: AgentConfig.defaultConfig,
        conversationHistory: [
          {
            'role': 'user',
            'content': intent.rawText,
          },
        ],
        maxSteps: 10,
        timeoutSeconds: 120,
        currentGoal: coreIntent.goal,
        intent: coreIntent,
        relevantMemory: memoryContext == null || memoryContext.isEmpty
            ? const []
            : [memoryContext],
      );

      final plan = await _agentEngine.planForOrchestration(
        userInput: intent.rawText,
        context: context,
      );

      return orchestration.AgentPlan(
        planId: plan.planId,
        intentId: intent.intentId,
        needsMemory: memoryContext != null && memoryContext.isNotEmpty,
        needsTool: intent.isToolAction && !plan.isEmpty,
        needsScreenAction: intent.isScreenAction,
        isDirectResponse: intent.isDirectResponse,
        suggestedResponse: plan.reasoning,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool requiresTool(orchestration.AgentPlan plan) {
    return plan.needsTool;
  }

  @override
  bool requiresScreenAction(orchestration.AgentPlan plan) {
    return plan.needsScreenAction;
  }

  core.IntentActionType _toCoreActionType(
    orchestration.AgentIntent intent,
  ) {
    if (intent.isDirectResponse) {
      return core.IntentActionType.conversation;
    }

    if (intent.isScreenAction) {
      return core.IntentActionType.control;
    }

    if (intent.isToolAction) {
      return core.IntentActionType.action;
    }

    return core.IntentActionType.conversation;
  }

  bool _isScreenAction(core.AgentIntent intent) {
    final text = [
      intent.goal,
      intent.expectedOutcome ?? '',
      ...intent.toolRequirements,
    ].join(' ').toLowerCase();

    const screenKeywords = <String>[
      'screen',
      'tap',
      'click',
      'swipe',
      'gesture',
      'شاشە',
      'کلیک',
      'کرتە',
      'سکرین',
      'دەستکاری',
    ];

    return screenKeywords.any(text.contains);
  }
}
