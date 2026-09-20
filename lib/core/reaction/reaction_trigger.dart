/// Trigger sources that can cause a reaction to fire.
///
/// Each trigger corresponds to a state change or event in the
/// AURA agent pipeline. The reaction engine uses [ReactionContext]
/// which captures the current state of these triggers to decide
/// which reactions are eligible.
library;

/// The event source that may trigger a reaction.
enum ReactionTrigger {
  /// [VoiceState] changed (idle → listening, listening → processing, etc.).
  voiceState,

  /// [AgentState] changed (idle → understanding, executing → completed, etc.).
  agentState,

  /// [AgentIntent] was parsed (actionType, confidence, entities resolved).
  agentIntent,

  /// Wake-word was detected ("ئەورا" / AURA or similar).
  wakeEvent,

  /// An error occurred in the agent pipeline or tool execution.
  errorEvent,

  /// A tool started or completed execution.
  toolExecution,

  /// Detected user tone (e.g. frustrated, happy, confused).
  userTone,

  /// Idle timeout — the system has been idle long enough to show
  /// a proactive reaction (e.g. idle hint, greeting).
  idleTimeout;

  /// Whether this trigger is a state-change trigger (vs. event trigger).
  bool get isStateChange =>
      this == ReactionTrigger.voiceState ||
      this == ReactionTrigger.agentState;

  /// Whether this trigger is a one-shot event (vs. continuous state).
  bool get isEvent =>
      this == ReactionTrigger.wakeEvent ||
      this == ReactionTrigger.errorEvent ||
      this == ReactionTrigger.toolExecution ||
      this == ReactionTrigger.idleTimeout;
}
