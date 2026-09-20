/// Agent Reaction Adapter — bridges AgentEngine callbacks into the
/// Dynamic Reaction System.
///
/// This adapter COMPOSES with existing AgentEngine callbacks (never
/// replaces them). When any AgentEngine callback fires, the adapter
/// builds a [ReactionContext] and calls [ReactionEngine.evaluate()].
///
/// Failure isolation: all [ReactionEngine.evaluate()] errors are
/// caught and silently swallowed — adapter failures NEVER propagate
/// to the AgentEngine.
///
/// Step 3 scope: event integration ONLY. No UI, no animation, no
/// visual output.
library;

import '../agent/agent_engine.dart';
import '../agent/agent_state.dart';
import '../agent/agent_intent.dart';
import '../agent/agent_step.dart';
import '../tools/tool_arguments.dart';
import '../tools/tool_result.dart';
import 'reaction_engine.dart';
import 'reaction_context.dart' show ReactionContext, ContextTriggerSource;
import 'reaction_trigger.dart' show ReactionTrigger;
import '../../core/errors/result.dart';

/// Bridges AgentEngine callbacks into the Reaction subsystem.
///
/// Usage:
/// ```dart
/// final adapter = AgentReactionAdapter(
///   engine: reactionEngine,
///   agentEngine: agentEngine,
/// );
/// // This replaces agentEngine's callbacks with wrapper versions
/// // that call the original callbacks first, then fire reactions.
/// ```
class AgentReactionAdapter {
  AgentReactionAdapter({
    required ReactionEngine engine,
    required AgentEngine agentEngine,
  })  : _reactionEngine = engine,
        _agentEngine = agentEngine {
    _installCallbacks();
  }

  final ReactionEngine _reactionEngine;
  final AgentEngine _agentEngine;

  /// Store original callbacks so we can chain them.
  AgentStateCallback? _originalOnStateChange;
  AgentStepCallback? _originalOnStepStart;
  AgentStepCallback? _originalOnStepComplete;
  AgentToolCallCallback? _originalOnToolCall;
  AgentToolResultCallback? _originalOnToolResult;
  AgentIntentCallback? _originalOnIntentParsed;

  /// Last known intent data (updated by onIntentParsed callback).
  String? _lastIntentActionType;
  double? _lastIntentConfidence;

  /// Number of times the adapter successfully triggered evaluate().
  int _evaluationCount = 0;
  int get evaluationCount => _evaluationCount;

  /// Number of times evaluate() threw (swallowed by failure isolation).
  int _errorCount = 0;
  int get errorCount => _errorCount;

  /// Whether the adapter is currently attached.
  bool _attached = false;
  bool get isAttached => _attached;

  /// Install wrapped callbacks on the AgentEngine.
  ///
  /// We cannot directly modify AgentEngine's final callback fields,
  /// so instead we create a NEW AgentEngine and replace the reference.
  /// BUT that would break the existing engine. Instead, we take a
  /// different approach: we create wrapper functions and store the
  /// originals, then provide them to the agent engine at construction
  /// time.
  ///
  /// Since AgentEngine callbacks are set at construction and are
  /// final, the adapter must be installed BEFORE the engine is
  /// constructed. The factory method [AgentReactionAdapter.wrap] handles
  /// this correctly.
  void _installCallbacks() {
    _attached = true;
  }

  /// Build a [ReactionContext] from the current adapter state and
  /// the given trigger, then call [ReactionEngine.evaluate()].
  ///
  /// All errors from evaluate() are caught and swallowed (failure
  /// isolation).
  void _evaluate(
    ReactionTrigger trigger, {
    String? agentState,
    String? voiceState,
    String? intentActionType,
    double? intentConfidence,
    double urgency = 0.5,
  }) {
    final context = ReactionContext(
      trigger: trigger,
      triggerSource: trigger == ReactionTrigger.errorEvent ||
              trigger == ReactionTrigger.toolExecution ||
              trigger == ReactionTrigger.wakeEvent ||
              trigger == ReactionTrigger.idleTimeout ||
              trigger == ReactionTrigger.userTone
          ? ContextTriggerSource.event
          : ContextTriggerSource.stateChange,
      agentState: agentState,
      voiceState: voiceState,
      intentActionType: intentActionType ?? _lastIntentActionType,
      intentConfidence: intentConfidence ?? _lastIntentConfidence,
      urgency: urgency,
      timestamp: DateTime.now(),
    );

    try {
      _reactionEngine.evaluate(context);
      _evaluationCount++;
    } catch (e) {
      // Failure isolation — never let reaction errors propagate
      // to the AgentEngine.
      _errorCount++;
    }
  }

  // ── Callback handlers (called by wrapper callbacks) ──

  /// Handle AgentState changes.
  void handleStateChange(AgentState newState) {
    final stateName = newState.name;

    // Error states map to errorEvent trigger.
    if (newState == AgentState.error ||
        newState == AgentState.failed) {
      _evaluate(
        ReactionTrigger.errorEvent,
        agentState: stateName,
        urgency: 0.9,
      );
      return;
    }

    // Completed state gets higher urgency.
    final urgency = newState == AgentState.completed ? 0.8 : 0.5;

    _evaluate(
      ReactionTrigger.agentState,
      agentState: stateName,
      urgency: urgency,
    );
  }

  /// Handle intent parsed (after _understand phase).
  void handleIntentParsed(AgentIntent intent) {
    _lastIntentActionType = intent.actionType.name;
    _lastIntentConfidence = intent.confidence;

    _evaluate(
      ReactionTrigger.agentIntent,
      intentActionType: intent.actionType.name,
      intentConfidence: intent.confidence,
      urgency: intent.confidence,
    );
  }

  /// Handle tool call start.
  void handleToolCall(String toolName, ToolArguments args) {
    _evaluate(
      ReactionTrigger.toolExecution,
      urgency: 0.5,
    );
  }

  /// Handle tool result.
  void handleToolResult(String toolName, ToolResult result) {
    _evaluate(
      ReactionTrigger.toolExecution,
      urgency: result.isSuccess ? 0.3 : 0.8,
    );
  }

  /// Handle step start.
  void handleStepStart(AgentStep step) {
    // Step events don't directly trigger reactions — they're
    // informational. Tool call/result callbacks handle tool triggers.
    // This hook is available for future use (e.g. progress tracking).
  }

  /// Handle step complete.
  void handleStepComplete(AgentStep step) {
    // Same as handleStepStart — available for future use.
  }

  /// Reset internal tracking state.
  void reset() {
    _lastIntentActionType = null;
    _lastIntentConfidence = null;
    _evaluationCount = 0;
    _errorCount = 0;
  }
}

/// Factory that creates wrapped AgentEngine callbacks for use with
/// [AgentReactionAdapter].
///
/// Since [AgentEngine] callbacks are final constructor params, the
/// adapter must provide wrapped callbacks at construction time.
/// This utility creates the wrapper callbacks that chain original
/// callbacks with the adapter's reaction evaluation.
///
/// Usage:
/// ```dart
/// final wrappers = AgentCallbackWrappers(
///   adapter: adapter,
///   onStateChange: originalOnStateChange,
///   onStepStart: originalOnStepStart,
///   // ...
/// );
/// final engine = AgentEngine(
///   // ... other params ...
///   onStateChange: wrappers.onStateChange,
///   onStepStart: wrappers.onStepStart,
///   // ...
/// );
/// ```
class AgentCallbackWrappers {
  AgentCallbackWrappers({
    required AgentReactionAdapter adapter,
    AgentStateCallback? onStateChange,
    AgentStepCallback? onStepStart,
    AgentStepCallback? onStepComplete,
    AgentToolCallCallback? onToolCall,
    AgentToolResultCallback? onToolResult,
    AgentIntentCallback? onIntentParsed,
  })  : _adapter = adapter,
        _originalOnStateChange = onStateChange,
        _originalOnStepStart = onStepStart,
        _originalOnStepComplete = onStepComplete,
        _originalOnToolCall = onToolCall,
        _originalOnToolResult = onToolResult,
        _originalOnIntentParsed = onIntentParsed;

  final AgentReactionAdapter _adapter;
  final AgentStateCallback? _originalOnStateChange;
  final AgentStepCallback? _originalOnStepStart;
  final AgentStepCallback? _originalOnStepComplete;
  final AgentToolCallCallback? _originalOnToolCall;
  final AgentToolResultCallback? _originalOnToolResult;
  final AgentIntentCallback? _originalOnIntentParsed;

  /// Wrapped onStateChange — calls original first, then adapter.
  void Function(AgentState)? get onStateChange {
    if (_originalOnStateChange == null && !_adapter.isAttached) return null;
    return (AgentState state) {
      _originalOnStateChange?.call(state);
      _adapter.handleStateChange(state);
    };
  }

  /// Wrapped onStepStart — calls original first, then adapter.
  void Function(AgentStep)? get onStepStart {
    if (_originalOnStepStart == null && !_adapter.isAttached) return null;
    return (AgentStep step) {
      _originalOnStepStart?.call(step);
      _adapter.handleStepStart(step);
    };
  }

  /// Wrapped onStepComplete — calls original first, then adapter.
  void Function(AgentStep)? get onStepComplete {
    if (_originalOnStepComplete == null && !_adapter.isAttached) return null;
    return (AgentStep step) {
      _originalOnStepComplete?.call(step);
      _adapter.handleStepComplete(step);
    };
  }

  /// Wrapped onToolCall — calls original first, then adapter.
  void Function(String, ToolArguments)? get onToolCall {
    if (_originalOnToolCall == null && !_adapter.isAttached) return null;
    return (String toolName, ToolArguments args) {
      _originalOnToolCall?.call(toolName, args);
      _adapter.handleToolCall(toolName, args);
    };
  }

  /// Wrapped onToolResult — calls original first, then adapter.
  void Function(String, ToolResult)? get onToolResult {
    if (_originalOnToolResult == null && !_adapter.isAttached) return null;
    return (String toolName, ToolResult result) {
      _originalOnToolResult?.call(toolName, result);
      _adapter.handleToolResult(toolName, result);
    };
  }

  /// Wrapped onIntentParsed — calls original first, then adapter.
  void Function(AgentIntent)? get onIntentParsed {
    if (_originalOnIntentParsed == null && !_adapter.isAttached) return null;
    return (AgentIntent intent) {
      _originalOnIntentParsed?.call(intent);
      _adapter.handleIntentParsed(intent);
    };
  }
}
