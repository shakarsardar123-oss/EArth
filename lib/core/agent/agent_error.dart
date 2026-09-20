import '../errors/failures.dart';

/// Agent-specific failure types.
class AgentFailure extends Failure {
  const AgentFailure({String? message, String? code})
      : super(message: message ?? 'Agent error', code: code);
}

class AgentPlanningFailure extends AgentFailure {
  const AgentPlanningFailure({String? message})
      : super(message: message ?? 'Planning failed', code: 'AGENT_PLAN_FAIL');
}

class AgentExecutionFailure extends AgentFailure {
  const AgentExecutionFailure({String? message})
      : super(message: message ?? 'Execution failed', code: 'AGENT_EXEC_FAIL');
}

class AgentResponseFailure extends AgentFailure {
  const AgentResponseFailure({String? message})
      : super(message: message ?? 'Response generation failed', code: 'AGENT_RESP_FAIL');
}

class AgentTimeoutFailure extends AgentFailure {
  const AgentTimeoutFailure({String? message})
      : super(message: message ?? 'Agent timed out', code: 'AGENT_TIMEOUT');
}

class AgentContextFailure extends AgentFailure {
  const AgentContextFailure({String? message})
      : super(message: message ?? 'Invalid agent context', code: 'AGENT_CTX_FAIL');
}
