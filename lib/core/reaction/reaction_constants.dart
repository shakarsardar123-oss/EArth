/// Constants for the AURA Dynamic Reaction System.
///
/// Follows the project pattern of abstract final classes with static
/// const string members (cf. FloatingAuraConstants).
///
/// These constants define the MethodChannel contract for the native
/// overlay (future Step 3+), default configuration values, and
/// category/tag names used by the catalog.
library;

/// Method names for the native overlay contract.
///
/// These will be used when dispatching reactions through the
/// MethodChannel to the Android native overlay (plain View).
abstract final class ReactionMethodNames {
  /// Instructs the native overlay to display the given reaction.
  static const String updateReaction = 'updateReaction';

  /// Instructs the native overlay to clear the current reaction.
  static const String clearReaction = 'clearReaction';

  /// Queries the native overlay for its current reaction state.
  static const String getReactionState = 'getReactionState';
}

/// Default configuration values for the reaction system.
abstract final class ReactionDefaults {
  /// Default cooldown between identical reactions.
  static const Duration defaultCooldown = Duration(seconds: 30);

  /// Default base priority for reactions.
  static const double defaultPriority = 0.5;

  /// Default weight multiplier.
  static const double defaultWeight = 1.0;

  /// Default history buffer size.
  static const int defaultHistorySize = 64;

  /// Default anti-repetition cooldown penalty.
  static const double cooldownPenalty = 0.85;

  /// Default anti-repetition recent-count penalty per occurrence.
  static const double recentCountPenalty = 0.3;

  /// Minimum weight threshold for selection eligibility.
  static const double minWeightThreshold = 0.001;
}

/// Standard category names for the reaction catalog.
abstract final class ReactionCategories {
  /// Voice-related reactions (listening, speaking indicators).
  static const String voice = 'voice';

  /// Agent-state reactions (processing, completed, failed).
  static const String agent = 'agent';

  /// Idle / proactive reactions (idle hints, greetings).
  static const String idle = 'idle';

  /// Error reactions (error messages, retry prompts).
  static const String error = 'error';

  /// Tool execution reactions (progress, result feedback).
  static const String tool = 'tool';

  /// Personality / humor reactions (jokes, encouragement).
  static const String personality = 'personality';
}

/// Standard tag names for reaction filtering.
abstract final class ReactionTags {
  /// Reaction provides feedback about current state.
  static const String feedback = 'feedback';

  /// Reaction shows proactive / idle behavior.
  static const String idleHint = 'idle_hint';

  /// Reaction is personality-driven (humor, encouragement).
  static const String personality = 'personality';

  /// Reaction is an error indicator.
  static const String error = 'error';

  /// Reaction confirms a completed action.
  static const String confirmation = 'confirmation';

  /// Reaction indicates progress / loading.
  static const String progress = 'progress';
}
