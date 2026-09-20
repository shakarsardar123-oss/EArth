import '../../domain/entities/agent_config.dart';
import 'agent_plan.dart';

/// State of a pending user confirmation request.
enum ConfirmationState {
  /// No confirmation pending.
  none,

  /// Waiting for user to approve.
  pending,

  /// User approved.
  approved,

  /// User denied.
  denied;
}

/// The execution context for an agent cycle.
///
/// Phase 4 adds: currentGoal, intent, plan, observations, toolHistory,
/// retryCount, executionBudget, confirmationState, relevantMemory —
/// all with defaults for backward compat.
class AgentContext {
  AgentContext({
    required this.agentConfig,
    this.conversationHistory = const [],
    this.maxSteps = 10,
    this.maxToolCallsPerStep = 5,
    this.timeoutSeconds = 120,
    // ── Phase 4 additions ──
    this.currentGoal,
    this.intent,
    this.plan,
    this.observations = const [],
    this.toolHistory = const [],
    this.retryCount = 0,
    this.executionBudget = const ExecutionBudget(),
    this.confirmationState = ConfirmationState.none,
    this.relevantMemory = const [],
  });

  /// The agent configuration for this execution.
  final AgentConfig agentConfig;

  /// Conversation history as list of message maps:
  /// { 'role': 'user'|'assistant'|'system'|'tool', 'content': '...', ... }
  final List<Map<String, dynamic>> conversationHistory;

  /// Maximum number of steps the agent can take.
  final int maxSteps;

  /// Maximum tool calls per single step.
  final int maxToolCallsPerStep;

  /// Timeout for the entire agent execution in seconds.
  final int timeoutSeconds;

  // ── Phase 4 additions ──

  /// The current high-level goal the agent is pursuing.
  final String? currentGoal;

  /// The parsed intent (may be null before understanding phase).
  final dynamic intent;

  /// The current execution plan.
  final AgentPlan? plan;

  /// Observations collected during execution.
  final List<AgentObservation> observations;

  /// History of all tool calls made so far.
  final List<ToolCallRecord> toolHistory;

  /// Number of overall retries so far.
  final int retryCount;

  /// Budget constraining execution resources.
  final ExecutionBudget executionBudget;

  /// Current confirmation request state.
  final ConfirmationState confirmationState;

  /// Relevant memory snippets recalled for this execution.
  final List<String> relevantMemory;

  // ── Original methods (preserved) ──

  /// Creates a new context with additional conversation history.
  AgentContext addMessage(Map<String, dynamic> message) => AgentContext(
        agentConfig: agentConfig,
        conversationHistory: [...conversationHistory, message],
        maxSteps: maxSteps,
        maxToolCallsPerStep: maxToolCallsPerStep,
        timeoutSeconds: timeoutSeconds,
        currentGoal: currentGoal,
        intent: intent,
        plan: plan,
        observations: observations,
        toolHistory: toolHistory,
        retryCount: retryCount,
        executionBudget: executionBudget,
        confirmationState: confirmationState,
        relevantMemory: relevantMemory,
      );

  /// Creates a new context with updated conversation history.
  AgentContext withHistory(List<Map<String, dynamic>> history) =>
      AgentContext(
        agentConfig: agentConfig,
        conversationHistory: history,
        maxSteps: maxSteps,
        maxToolCallsPerStep: maxToolCallsPerStep,
        timeoutSeconds: timeoutSeconds,
        currentGoal: currentGoal,
        intent: intent,
        plan: plan,
        observations: observations,
        toolHistory: toolHistory,
        retryCount: retryCount,
        executionBudget: executionBudget,
        confirmationState: confirmationState,
        relevantMemory: relevantMemory,
      );

  // ── Phase 4 convenience methods ──

  /// Add an observation.
  AgentContext addObservation(AgentObservation obs) => AgentContext(
        agentConfig: agentConfig,
        conversationHistory: conversationHistory,
        maxSteps: maxSteps,
        maxToolCallsPerStep: maxToolCallsPerStep,
        timeoutSeconds: timeoutSeconds,
        currentGoal: currentGoal,
        intent: intent,
        plan: plan,
        observations: [...observations, obs],
        toolHistory: toolHistory,
        retryCount: retryCount,
        executionBudget: executionBudget,
        confirmationState: confirmationState,
        relevantMemory: relevantMemory,
      );

  /// Record a tool call.
  AgentContext recordToolCall(ToolCallRecord record) => AgentContext(
        agentConfig: agentConfig,
        conversationHistory: conversationHistory,
        maxSteps: maxSteps,
        maxToolCallsPerStep: maxToolCallsPerStep,
        timeoutSeconds: timeoutSeconds,
        currentGoal: currentGoal,
        intent: intent,
        plan: plan,
        observations: observations,
        toolHistory: [...toolHistory, record],
        retryCount: retryCount,
        executionBudget: executionBudget,
        confirmationState: confirmationState,
        relevantMemory: relevantMemory,
      );

  /// Increment retry count.
  AgentContext incrementRetry() => AgentContext(
        agentConfig: agentConfig,
        conversationHistory: conversationHistory,
        maxSteps: maxSteps,
        maxToolCallsPerStep: maxToolCallsPerStep,
        timeoutSeconds: timeoutSeconds,
        currentGoal: currentGoal,
        intent: intent,
        plan: plan,
        observations: observations,
        toolHistory: toolHistory,
        retryCount: retryCount + 1,
        executionBudget: executionBudget,
        confirmationState: confirmationState,
        relevantMemory: relevantMemory,
      );

  /// Update context with new values.
  AgentContext update({
    String? currentGoal,
    dynamic intent,
    AgentPlan? plan,
    List<AgentObservation>? observations,
    List<ToolCallRecord>? toolHistory,
    int? retryCount,
    ExecutionBudget? executionBudget,
    ConfirmationState? confirmationState,
    List<String>? relevantMemory,
  }) =>
      AgentContext(
        agentConfig: agentConfig,
        conversationHistory: conversationHistory,
        maxSteps: maxSteps,
        maxToolCallsPerStep: maxToolCallsPerStep,
        timeoutSeconds: timeoutSeconds,
        currentGoal: currentGoal ?? this.currentGoal,
        intent: intent ?? this.intent,
        plan: plan ?? this.plan,
        observations: observations ?? this.observations,
        toolHistory: toolHistory ?? this.toolHistory,
        retryCount: retryCount ?? this.retryCount,
        executionBudget: executionBudget ?? this.executionBudget,
        confirmationState: confirmationState ?? this.confirmationState,
        relevantMemory: relevantMemory ?? this.relevantMemory,
      );

  /// Whether the execution budget has been exceeded.
  bool get isBudgetExceeded =>
      executionBudget.isExceeded(toolHistory.length, retryCount);

  @override
  String toString() =>
      'AgentContext(goal: $currentGoal, history: ${conversationHistory.length} msgs, retries: $retryCount, budget: $executionBudget)';
}

/// Budget constraints for agent execution.
class ExecutionBudget {
  const ExecutionBudget({
    this.maxToolCalls = 50,
    this.maxRetries = 10,
    this.maxExecutionTimeMs = 120000,
  });

  final int maxToolCalls;
  final int maxRetries;
  final int maxExecutionTimeMs;

  bool isExceeded(int toolCallCount, int retryCount) =>
      toolCallCount > maxToolCalls || retryCount > maxRetries;

  @override
  String toString() =>
      'ExecutionBudget(tools: $maxToolCalls, retries: $maxRetries, time: ${maxExecutionTimeMs}ms)';
}

/// A structured observation collected during execution.
class AgentObservation {
  AgentObservation({
    required this.stepId,
    required this.toolName,
    required this.summary,
    this.data,
    DateTime? timestamp,
    this.relevance = Relevance.normal,
  })  : timestamp = timestamp ?? DateTime.now();

  final String stepId;
  final String toolName;
  final String summary;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
  final Relevance relevance;

  @override
  String toString() => 'AgentObservation($toolName: $summary)';
}

/// Relevance level of an observation.
enum Relevance {
  low,
  normal,
  high,
  critical;
}

/// Record of a single tool call.
class ToolCallRecord {
  ToolCallRecord({
    required this.stepId,
    required this.toolName,
    required this.parameters,
    this.result,
    DateTime? timestamp,
    this.durationMs,
    this.success = false,
    this.errorCode,
    this.retryAttempt = 0,
    String? recordId,
  })  : recordId = recordId ?? '',
        timestamp = timestamp ?? DateTime.now();

  final String recordId;
  final String stepId;
  final String toolName;
  final Map<String, dynamic> parameters;
  final dynamic result;
  final DateTime timestamp;
  final int? durationMs;
  final bool success;
  final String? errorCode;
  final int retryAttempt;

  @override
  String toString() =>
      'ToolCallRecord($toolName, success: $success, attempt: $retryAttempt)';
}
