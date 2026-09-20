/// Re-export observation types from agent_context.dart for convenience.
///
/// AgentObservation and Relevance are defined in agent_context.dart
/// because they are tightly coupled to the AgentContext state.
/// This barrel file provides a clean import path.
library;

export 'agent_context.dart' show AgentObservation, Relevance;
