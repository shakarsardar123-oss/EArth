/// Immutable context snapshot for reaction selection.
///
/// The [ReactionEngine] builds a [ReactionContext] from the current
/// system state and passes it to the [ReactionSelector]. The selector
/// uses these fields to determine which reactions are eligible.
///
/// All fields are snapshotted at evaluation time — no streams or
/// async access needed.
library;

import 'package:meta/meta.dart' show immutable;

import 'reaction_trigger.dart';

/// The specific trigger that caused this evaluation.
enum ContextTriggerSource {
  /// No specific trigger — periodic or idle evaluation.
  none,

  /// A state change occurred (voice, agent, intent).
  stateChange,

  /// An event occurred (wake, error, tool, idle timeout).
  event;
}

/// User tone detection result.
enum UserTone {
  /// Tone not determined (default).
  unknown,

  /// User appears frustrated or impatient.
  frustrated,

  /// User appears happy or satisfied.
  happy,

  /// User appears confused or uncertain.
  confused,

  /// Normal, neutral tone.
  neutral;
}

/// Mood hint from the intelligence layer (Step 4).
///
/// A coarse-grained mood classification derived deterministically
/// from [ReactionContext] signals. This is NOT an ML prediction —
/// it is a rule-based classification used to influence style selection.
enum ReactionMoodHint {
  /// No mood signal detected (default).
  none,

  /// System is in an upbeat / positive state (completed, wake, happy tone).
  upbeat,

  /// System is in a focused / productive state (executing, processing).
  focused,

  /// System is in a stressed / error state (error, failed, frustrated tone).
  stressed,

  /// System is in a relaxed / idle state (idle timeout, idle voice).
  relaxed,

  /// System is in a curious / exploratory state (low confidence, confused tone).
  curious;
}

/// Playfulness level (0.0–1.0) — how playful the reaction may be.
///
/// Higher values suggest the system should prefer humorous / meme / fun
/// reactions over dry / technical ones. Lower values suggest seriousness.
///
/// Default is 0.5 (moderate). Error contexts default to 0.1 (serious).
/// Idle contexts default to 0.7 (playful).

/// Snapshot of the system state at the moment a reaction is evaluated.
///
/// Constructed by the [ReactionEngine] from live providers and passed
/// to the [ReactionSelector] for deterministic selection.
@immutable
class ReactionContext {
  const ReactionContext({
    required this.trigger,
    this.triggerSource = ContextTriggerSource.stateChange,
    this.voiceState,
    this.agentState,
    this.intentActionType,
    this.intentConfidence,
    this.urgency = 0.5,
    this.userTone = UserTone.unknown,
    this.moodHint = ReactionMoodHint.none,
    this.playfulnessLevel = 0.5,
    required this.timestamp,
    this.seed,
  });

  /// The trigger that caused this evaluation.
  final ReactionTrigger trigger;

  /// Whether this was triggered by a state change or a discrete event.
  final ContextTriggerSource triggerSource;

  /// Current [VoiceState] name (e.g. 'idle', 'listening', 'processing',
  /// 'speaking', 'error'). null if voice is not active.
  final String? voiceState;

  /// Current [AgentState] name (e.g. 'idle', 'understanding', 'executing',
  /// 'completed', 'failed', etc.). null if agent is not active.
  final String? agentState;

  /// Current [IntentActionType] name (e.g. 'query', 'action', 'conversation',
  /// etc.). null if no intent has been parsed.
  final String? intentActionType;

  /// Confidence of the parsed intent (0.0–1.0). null if no intent.
  final double? intentConfidence;

  /// System urgency level (0.0–1.0) — higher = more urgent context.
  final double urgency;

  /// Detected user tone.
  final UserTone userTone;

  /// Mood hint from the intelligence layer (Step 4).
  ///
  /// Set by [ReactionMoodClassifier] before selection.
  /// Default is [ReactionMoodHint.none] (no mood signal).
  final ReactionMoodHint moodHint;

  /// Playfulness level (0.0–1.0) — how playful the reaction may be.
  ///
  /// 0.0 = very serious (errors, critical urgency)
  /// 0.5 = moderate (default)
  /// 1.0 = very playful (idle, happy tone)
  final double playfulnessLevel;

  /// When this context was created.
  final DateTime timestamp;

  /// Optional seed for deterministic random selection (testing).
  /// If null, the [RandomSource] uses its own seed.
  final int? seed;

  /// Whether the context indicates an active (non-idle) agent.
  bool get isAgentActive =>
      agentState != null &&
      agentState != 'idle' &&
      agentState != 'completed' &&
      agentState != 'failed' &&
      agentState != 'cancelled';

  /// Whether the context indicates an active (non-idle) voice.
  bool get isVoiceActive =>
      voiceState != null &&
      voiceState != 'idle' &&
      voiceState != 'error';

  /// Whether the context indicates an error state.
  bool get isError =>
      voiceState == 'error' ||
      agentState == 'error' ||
      agentState == 'failed';

  ReactionContext copyWith({
    ReactionTrigger? trigger,
    ContextTriggerSource? triggerSource,
    String? voiceState,
    String? agentState,
    String? intentActionType,
    double? intentConfidence,
    double? urgency,
    UserTone? userTone,
    ReactionMoodHint? moodHint,
    double? playfulnessLevel,
    DateTime? timestamp,
    int? seed,
  }) {
    return ReactionContext(
      trigger: trigger ?? this.trigger,
      triggerSource: triggerSource ?? this.triggerSource,
      voiceState: voiceState ?? this.voiceState,
      agentState: agentState ?? this.agentState,
      intentActionType: intentActionType ?? this.intentActionType,
      intentConfidence: intentConfidence ?? this.intentConfidence,
      urgency: urgency ?? this.urgency,
      userTone: userTone ?? this.userTone,
      moodHint: moodHint ?? this.moodHint,
      playfulnessLevel: playfulnessLevel ?? this.playfulnessLevel,
      timestamp: timestamp ?? this.timestamp,
      seed: seed ?? this.seed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReactionContext &&
        other.trigger == trigger &&
        other.triggerSource == triggerSource &&
        other.voiceState == voiceState &&
        other.agentState == agentState &&
        other.intentActionType == intentActionType &&
        other.intentConfidence == intentConfidence &&
        other.urgency == urgency &&
        other.userTone == userTone &&
        other.moodHint == moodHint &&
        other.playfulnessLevel == playfulnessLevel &&
        other.seed == seed;
  }

  @override
  int get hashCode => Object.hash(
        trigger,
        triggerSource,
        voiceState,
        agentState,
        intentActionType,
        intentConfidence,
        urgency,
        userTone,
        moodHint,
        playfulnessLevel,
        seed,
      );

  @override
  String toString() =>
      'ReactionContext(trigger: $trigger, voice: $voiceState, '
      'agent: $agentState, intent: $intentActionType, '
      'urgency: $urgency, tone: $userTone, '
      'mood: $moodHint, playfulness: $playfulnessLevel)';
}
