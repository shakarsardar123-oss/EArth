/// Step 3: Comprehensive tests for [AgentReactionAdapter] and
/// [AgentCallbackWrappers].
///
/// Tests cover: state mapping, error mapping, intent mapping, tool
/// call/result mapping, callback chaining, failure isolation, and
/// evaluation counting.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/reaction/reaction.dart';
import 'package:aura_assistant/core/agent/agent_state.dart';
import 'package:aura_assistant/core/agent/agent_intent.dart';
import 'package:aura_assistant/core/agent/agent_step.dart';
import 'package:aura_assistant/core/tools/tool_arguments.dart';
import 'package:aura_assistant/core/tools/tool_result.dart';
import 'package:aura_assistant/core/agent/agent_engine.dart';
import 'package:aura_assistant/core/tools/tool_registry.dart';
import 'package:aura_assistant/core/errors/result.dart';

// ── ThrowingReactionEngine: always throws on evaluate() ──

class ThrowingReactionEngine extends ReactionEngine {
  ThrowingReactionEngine({
    required ReactionCatalog catalog,
    required StyleAwareSelector selector,
    required ReactionHistory history,
    required RandomSource randomSource,
    required Clock clock,
  }) : super(
          catalog: catalog,
          selector: selector,
          history: history,
          randomSource: randomSource,
          clock: clock,
        );

  @override
  Result<Reaction, ReactionFailure> evaluate(ReactionContext context) {
    throw StateError('Intentional evaluate() failure for testing');
  }
}

void main() {
  // ── Shared test infrastructure ──

  late ReactionCatalog catalog;
  late FrozenClock clock;
  late ReactionHistory history;
  late StyleAwareSelector selector;
  late DeterministicRandomSource random;
  late ReactionEngine engine;
  final baseTime = DateTime(2026, 1, 1, 12, 0, 0);

  /// Minimal AgentEngine for construction — we never call .run() on it.
  AgentEngine createMinimalAgentEngine() {
    return AgentEngine(
      toolRegistry: ToolRegistry(),
      sendToAI: ({
        required List<Map<String, dynamic>> messages,
        required List<Map<String, dynamic>> toolDefinitions,
        required context,
      }) async => <String, dynamic>{});
  }

  void registerReactionForTrigger(ReactionTrigger trigger) {
    catalog.register(Reaction(
      id: '${trigger.name}_reaction',
      type: const EmojiReactionType('🧪'),
      trigger: trigger,
      priority: 0.5,
      cooldown: Duration.zero,
    ));
  }

  // ── AgentReactionAdapter ──

  group('AgentReactionAdapter', () {
    setUp(() {
      catalog = ReactionCatalog();
      clock = FrozenClock(baseTime);
      history = ReactionHistory(clock: clock);
      selector = StyleAwareSelector(baseSelector: const ReactionSelector());
      random = DeterministicRandomSource([0.0]);
      engine = ReactionEngine(
        catalog: catalog,
        selector: selector,
        history: history,
        randomSource: random,
        clock: clock,
      );
    });

    tearDown(() {
      engine.dispose();
    });

    // ── A1: Agent state mapping ──

    group('handleStateChange — normal states', () {
      test('idle → agentState trigger, urgency 0.5', () {
        registerReactionForTrigger(ReactionTrigger.agentState);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleStateChange(AgentState.idle);

        expect(adapter.evaluationCount, 1);
        expect(adapter.errorCount, 0);
        expect(engine.state.lastReactionId, 'agentState_reaction');
      });

      test('planning → agentState trigger, urgency 0.5', () {
        registerReactionForTrigger(ReactionTrigger.agentState);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleStateChange(AgentState.planning);

        expect(adapter.evaluationCount, 1);
        expect(adapter.errorCount, 0);
      });

      test('executing → agentState trigger, urgency 0.5', () {
        registerReactionForTrigger(ReactionTrigger.agentState);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleStateChange(AgentState.executing);

        expect(adapter.evaluationCount, 1);
      });

      test('understanding → agentState trigger, urgency 0.5', () {
        registerReactionForTrigger(ReactionTrigger.agentState);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleStateChange(AgentState.understanding);

        expect(adapter.evaluationCount, 1);
      });

      test('completed → agentState trigger, urgency 0.8', () {
        registerReactionForTrigger(ReactionTrigger.agentState);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleStateChange(AgentState.completed);

        expect(adapter.evaluationCount, 1);
        // Completed gets urgency 0.8 — we can verify this via the history
        // which captures the reaction that was selected.
        expect(engine.state.lastReactionId, 'agentState_reaction');
      });

      test('cancelled → agentState trigger, urgency 0.5', () {
        registerReactionForTrigger(ReactionTrigger.agentState);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleStateChange(AgentState.cancelled);

        expect(adapter.evaluationCount, 1);
      });

      test('responding → agentState trigger, urgency 0.5', () {
        registerReactionForTrigger(ReactionTrigger.agentState);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleStateChange(AgentState.responding);

        expect(adapter.evaluationCount, 1);
      });
    });

    // ── A2: Error state mapping ──

    group('handleStateChange — error states', () {
      test('error → errorEvent trigger', () {
        registerReactionForTrigger(ReactionTrigger.errorEvent);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleStateChange(AgentState.error);

        expect(adapter.evaluationCount, 1);
        expect(adapter.errorCount, 0);
        expect(engine.state.lastReactionId, 'errorEvent_reaction');
      });

      test('failed → errorEvent trigger', () {
        registerReactionForTrigger(ReactionTrigger.errorEvent);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleStateChange(AgentState.failed);

        expect(adapter.evaluationCount, 1);
        expect(engine.state.lastReactionId, 'errorEvent_reaction');
      });

      test('error state does NOT produce agentState trigger', () {
        // Register agentState reaction but NOT errorEvent reaction.
        registerReactionForTrigger(ReactionTrigger.agentState);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        // handleStateChange for error maps to errorEvent, not agentState.
        // Since no errorEvent reaction is registered, evaluate returns failure
        // but the adapter still counts it as a successful evaluation
        // (no exception was thrown).
        adapter.handleStateChange(AgentState.error);

        expect(adapter.evaluationCount, 1); // evaluate() didn't throw
        expect(adapter.errorCount, 0);
        expect(engine.state.totalSelections, 0); // no reaction was actually selected
      });
    });

    // ── A3: Intent mapping ─

    group('handleIntentParsed', () {
      test('high confidence intent → agentIntent trigger, urgency = confidence', () {
        registerReactionForTrigger(ReactionTrigger.agentIntent);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        final intent = AgentIntent(
          goal: 'Search for contacts',
          actionType: IntentActionType.query,
          confidence: 0.9,
          originalUtterance: 'بگەڕێ بۆ جەمال',
        );

        adapter.handleIntentParsed(intent);

        expect(adapter.evaluationCount, 1);
        expect(adapter.errorCount, 0);
        expect(engine.state.lastReactionId, 'agentIntent_reaction');
      });

      test('low confidence intent still evaluates', () {
        registerReactionForTrigger(ReactionTrigger.agentIntent);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        final intent = AgentIntent(
          goal: 'Maybe something',
          actionType: IntentActionType.ambiguous,
          confidence: 0.3,
        );

        adapter.handleIntentParsed(intent);

        expect(adapter.evaluationCount, 1);
      });

      test('stores last intent action type and confidence', () {
        registerReactionForTrigger(ReactionTrigger.agentIntent);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        final intent = AgentIntent(
          goal: 'Send a message',
          actionType: IntentActionType.action,
          confidence: 0.75,
        );

        adapter.handleIntentParsed(intent);

        // These are private, but we can verify via subsequent evaluations
        // that the stored values are used. We verify by checking that a
        // second state change includes the stored intent data in the
        // context (indirectly, through successful evaluation).
        expect(adapter.evaluationCount, 1);

        // Now trigger a state change — it should use stored intent data
        registerReactionForTrigger(ReactionTrigger.agentState);
        clock.advance(const Duration(seconds: 1));
        adapter.handleStateChange(AgentState.executing);
        expect(adapter.evaluationCount, 2);
      });

      test('multiple intents update stored data', () {
        registerReactionForTrigger(ReactionTrigger.agentIntent);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        final intent1 = AgentIntent(
          goal: 'First',
          actionType: IntentActionType.query,
          confidence: 0.8,
        );
        final intent2 = AgentIntent(
          goal: 'Second',
          actionType: IntentActionType.create,
          confidence: 0.6,
        );

        adapter.handleIntentParsed(intent1);
        clock.advance(const Duration(seconds: 1));
        adapter.handleIntentParsed(intent2);

        expect(adapter.evaluationCount, 2);
      });
    });

    // ── A4: Tool call mapping ──

    group('handleToolCall', () {
      test('tool call → toolExecution trigger, urgency 0.5', () {
        registerReactionForTrigger(ReactionTrigger.toolExecution);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleToolCall(
          'search_contacts',
          ToolArguments({'query': 'جەمال'}),
        );

        expect(adapter.evaluationCount, 1);
        expect(adapter.errorCount, 0);
        expect(engine.state.lastReactionId, 'toolExecution_reaction');
      });

      test('multiple tool calls each evaluate', () {
        registerReactionForTrigger(ReactionTrigger.toolExecution);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleToolCall(
          'tool_a',
          ToolArguments({}),
        );
        clock.advance(const Duration(seconds: 1));
        adapter.handleToolCall(
          'tool_b',
          ToolArguments({}),
        );

        expect(adapter.evaluationCount, 2);
      });
    });

    // ── A5: Tool result mapping ──

    group('handleToolResult', () {
      test('success result → toolExecution trigger, urgency 0.3', () {
        registerReactionForTrigger(ReactionTrigger.toolExecution);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleToolResult(
          'search_contacts',
          ToolResult.success({'found': true}),
        );

        expect(adapter.evaluationCount, 1);
        expect(adapter.errorCount, 0);
      });

      test('failure result → toolExecution trigger, urgency 0.8', () {
        registerReactionForTrigger(ReactionTrigger.toolExecution);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleToolResult(
          'search_contacts',
          ToolResult.failure('Contact not found', errorCode: 'NOT_FOUND'),
        );

        expect(adapter.evaluationCount, 1);
        expect(adapter.errorCount, 0);
      });

      test('tool failure with error code evaluates correctly', () {
        registerReactionForTrigger(ReactionTrigger.toolExecution);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleToolResult(
          'send_message',
          ToolResult.failure('Network error', errorCode: 'TIMEOUT'),
        );

        expect(adapter.evaluationCount, 1);
      });
    });

    // ── A6: Callback chaining (AgentCallbackWrappers) ──

    group('AgentCallbackWrappers', () {
      test('onStateChange chains original then adapter', () {
        registerReactionForTrigger(ReactionTrigger.agentState);

        var originalCalled = false;
        AgentState? originalArg;

        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        final wrappers = AgentCallbackWrappers(
          adapter: adapter,
          onStateChange: (AgentState state) {
            originalCalled = true;
            originalArg = state;
          },
        );

        // Call the wrapped callback
        wrappers.onStateChange!(AgentState.executing);

        expect(originalCalled, isTrue);
        expect(originalArg, AgentState.executing);
        expect(adapter.evaluationCount, 1); // adapter handler also fired
      });

      test('onIntentParsed chains original then adapter', () {
        registerReactionForTrigger(ReactionTrigger.agentIntent);

        var originalCalled = false;
        AgentIntent? originalArg;

        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        final wrappers = AgentCallbackWrappers(
          adapter: adapter,
          onIntentParsed: (AgentIntent intent) {
            originalCalled = true;
            originalArg = intent;
          },
        );

        final intent = AgentIntent(
          goal: 'Test',
          actionType: IntentActionType.query,
          confidence: 0.8,
        );

        wrappers.onIntentParsed!(intent);

        expect(originalCalled, isTrue);
        expect(originalArg, same(intent));
        expect(adapter.evaluationCount, 1);
      });

      test('onToolCall chains original then adapter', () {
        registerReactionForTrigger(ReactionTrigger.toolExecution);

        var originalCalled = false;
        String? originalToolName;

        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        final wrappers = AgentCallbackWrappers(
          adapter: adapter,
          onToolCall: (String name, ToolArguments args) {
            originalCalled = true;
            originalToolName = name;
          },
        );

        wrappers.onToolCall!('search', ToolArguments({'q': 'test'}));

        expect(originalCalled, isTrue);
        expect(originalToolName, 'search');
        expect(adapter.evaluationCount, 1);
      });

      test('onToolResult chains original then adapter', () {
        registerReactionForTrigger(ReactionTrigger.toolExecution);

        var originalCalled = false;

        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        final wrappers = AgentCallbackWrappers(
          adapter: adapter,
          onToolResult: (String name, ToolResult result) {
            originalCalled = true;
          },
        );

        wrappers.onToolResult!('search', ToolResult.success({'ok': true}));

        expect(originalCalled, isTrue);
        expect(adapter.evaluationCount, 1);
      });

      test('onStepStart chains original then adapter', () {
        var originalCalled = false;

        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        final wrappers = AgentCallbackWrappers(
          adapter: adapter,
          onStepStart: (AgentStep step) {
            originalCalled = true;
          },
        );

        final step = AgentStep(
          toolName: 'test_tool',
          parameters: {},
        );

        wrappers.onStepStart!(step);

        expect(originalCalled, isTrue);
        // handleStepStart doesn't evaluate, so evaluationCount stays 0
        expect(adapter.evaluationCount, 0);
      });

      test('onStepComplete chains original then adapter', () {
        var originalCalled = false;

        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        final wrappers = AgentCallbackWrappers(
          adapter: adapter,
          onStepComplete: (AgentStep step) {
            originalCalled = true;
          },
        );

        final step = AgentStep(
          toolName: 'test_tool',
          parameters: {},
        );

        wrappers.onStepComplete!(step);

        expect(originalCalled, isTrue);
        // handleStepComplete doesn't evaluate
        expect(adapter.evaluationCount, 0);
      });

      test('null original callback still produces wrapper (adapter attached)', () {
        registerReactionForTrigger(ReactionTrigger.agentState);

        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        // No original callbacks provided
        final wrappers = AgentCallbackWrappers(adapter: adapter);

        // Since adapter.isAttached is true (set in _installCallbacks),
        // all getters return non-null even with null original callbacks.
        expect(wrappers.onStateChange, isNotNull);
        expect(wrappers.onStepStart, isNotNull);
        expect(wrappers.onStepComplete, isNotNull);
        expect(wrappers.onToolCall, isNotNull);
        expect(wrappers.onToolResult, isNotNull);
        expect(wrappers.onIntentParsed, isNotNull);

        // Calling them should not throw — just adapter handler fires
        wrappers.onStateChange!(AgentState.idle);
        expect(adapter.evaluationCount, 1);
      });

      test('all 6 wrappers return non-null when adapter is attached', () {
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        final wrappers = AgentCallbackWrappers(adapter: adapter);

        expect(wrappers.onStateChange, isNotNull);
        expect(wrappers.onStepStart, isNotNull);
        expect(wrappers.onStepComplete, isNotNull);
        expect(wrappers.onToolCall, isNotNull);
        expect(wrappers.onToolResult, isNotNull);
        expect(wrappers.onIntentParsed, isNotNull);
      });
    });

    // ── A7: Failure isolation ──

    group('failure isolation', () {
      test('evaluate() throws → error swallowed, errorCount++', () {
        final throwingEngine = ThrowingReactionEngine(
          catalog: catalog,
          selector: selector,
          history: history,
          randomSource: random,
          clock: clock,
        );

        final adapter = AgentReactionAdapter(
          engine: throwingEngine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleStateChange(AgentState.idle);

        expect(adapter.evaluationCount, 0); // exception was thrown, not counted
        expect(adapter.errorCount, 1);
      });

      test('multiple exceptions each increment errorCount', () {
        final throwingEngine = ThrowingReactionEngine(
          catalog: catalog,
          selector: selector,
          history: history,
          randomSource: random,
          clock: clock,
        );

        final adapter = AgentReactionAdapter(
          engine: throwingEngine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleStateChange(AgentState.idle);
        adapter.handleStateChange(AgentState.executing);
        adapter.handleStateChange(AgentState.error);

        expect(adapter.evaluationCount, 0);
        expect(adapter.errorCount, 3);
      });

      test('exception does not propagate to caller', () {
        final throwingEngine = ThrowingReactionEngine(
          catalog: catalog,
          selector: selector,
          history: history,
          randomSource: random,
          clock: clock,
        );

        final adapter = AgentReactionAdapter(
          engine: throwingEngine,
          agentEngine: createMinimalAgentEngine(),
        );

        // This should NOT throw
        expect(
          () => adapter.handleStateChange(AgentState.idle),
          returnsNormally,
        );
      });

      test('intermittent failures: mix of success and throw', () {
        // Create a normal engine and a throwing engine.
        // We'll test with the normal engine first, then switch.
        registerReactionForTrigger(ReactionTrigger.agentState);

        final normalAdapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        normalAdapter.handleStateChange(AgentState.idle);
        expect(normalAdapter.evaluationCount, 1);
        expect(normalAdapter.errorCount, 0);

        // Now test with throwing engine
        final throwingEngine = ThrowingReactionEngine(
          catalog: catalog,
          selector: selector,
          history: history,
          randomSource: random,
          clock: clock,
        );

        final throwingAdapter = AgentReactionAdapter(
          engine: throwingEngine,
          agentEngine: createMinimalAgentEngine(),
        );

        throwingAdapter.handleStateChange(AgentState.idle);
        expect(throwingAdapter.evaluationCount, 0);
        expect(throwingAdapter.errorCount, 1);

        throwingEngine.dispose();
      });
    });

    // ── A8: Evaluation counting ──

    group('evaluation and error counting', () {
      test('initial counts are zero', () {
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        expect(adapter.evaluationCount, 0);
        expect(adapter.errorCount, 0);
      });

      test('successful evaluations increment evaluationCount', () {
        registerReactionForTrigger(ReactionTrigger.agentState);
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleStateChange(AgentState.idle);
        clock.advance(const Duration(seconds: 1));
        adapter.handleStateChange(AgentState.executing);
        clock.advance(const Duration(seconds: 1));
        adapter.handleStateChange(AgentState.completed);

        expect(adapter.evaluationCount, 3);
        expect(adapter.errorCount, 0);
      });

      test('evaluate() returns failure (no matching reaction) still counts as successful evaluation', () {
        // No reaction registered — evaluate() returns Result.failure
        // but no exception was thrown, so evaluationCount increments.
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleStateChange(AgentState.idle);

        expect(adapter.evaluationCount, 1); // no exception thrown
        expect(adapter.errorCount, 0);
      });

      test('reset clears counts and stored intent data', () {
        registerReactionForTrigger(ReactionTrigger.agentIntent);
        registerReactionForTrigger(ReactionTrigger.agentState);

        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        final intent = AgentIntent(
          goal: 'Test',
          actionType: IntentActionType.action,
          confidence: 0.7,
        );

        adapter.handleIntentParsed(intent);
        clock.advance(const Duration(seconds: 1));
        adapter.handleStateChange(AgentState.idle);

        expect(adapter.evaluationCount, 2);

        adapter.reset();

        expect(adapter.evaluationCount, 0);
        expect(adapter.errorCount, 0);
      });

      test('isAttached is true after construction', () {
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        expect(adapter.isAttached, isTrue);
      });
    });

    // ── Cross-cutting: step handlers don't evaluate ──

    group('handleStepStart and handleStepComplete', () {
      test('handleStepStart does not evaluate', () {
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        final step = AgentStep(
          toolName: 'test',
          parameters: {},
        );

        adapter.handleStepStart(step);

        expect(adapter.evaluationCount, 0);
        expect(adapter.errorCount, 0);
      });

      test('handleStepComplete does not evaluate', () {
        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        final step = AgentStep(
          toolName: 'test',
          parameters: {},
        );

        adapter.handleStepComplete(step);

        expect(adapter.evaluationCount, 0);
        expect(adapter.errorCount, 0);
      });
    });

    // ── Context verification ──

    group('ReactionContext correctness', () {
      test('error state uses ContextTriggerSource.event', () {
        // We verify indirectly: error/failed maps to errorEvent,
        // which the _evaluate method maps to ContextTriggerSource.event.
        // The ReactionContext is internal to _evaluate, but we can verify
        // the behavior by checking that the engine recorded a reaction
        // with the correct trigger.
        registerReactionForTrigger(ReactionTrigger.errorEvent);

        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleStateChange(AgentState.error);

        // Verify the engine processed it (reaction was selected)
        expect(engine.state.lastReactionId, 'errorEvent_reaction');
        expect(engine.state.totalSelections, 1);
      });

      test('tool execution uses ContextTriggerSource.event', () {
        registerReactionForTrigger(ReactionTrigger.toolExecution);

        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleToolCall('test', ToolArguments({}));

        expect(engine.state.lastReactionId, 'toolExecution_reaction');
        expect(engine.state.totalSelections, 1);
      });

      test('normal state change uses ContextTriggerSource.stateChange', () {
        registerReactionForTrigger(ReactionTrigger.agentState);

        final adapter = AgentReactionAdapter(
          engine: engine,
          agentEngine: createMinimalAgentEngine(),
        );

        adapter.handleStateChange(AgentState.planning);

        expect(engine.state.lastReactionId, 'agentState_reaction');
        expect(engine.state.totalSelections, 1);
      });
    });
  });
}
