/// Centralized constants for the AURA VoiceScreenEngine orchestrator.
///
/// All pipeline timeouts, throttling values, session defaults,
/// and stale-result protection parameters are defined here.
/// Do not scatter magic numbers throughout the engine.
library;

/// Timeouts for each pipeline stage.
class VoiceScreenTimeouts {
  const VoiceScreenTimeouts._();

  /// Maximum duration for the full voice→search pipeline.
  static const Duration pipeline = Duration(seconds: 30);

  /// Maximum duration for screen capture to produce a frame.
  static const Duration capture = Duration(seconds: 10);

  /// Maximum duration for screen-understanding analysis.
  static const Duration understanding = Duration(seconds: 15);

  /// Maximum duration for screen search.
  static const Duration search = Duration(seconds: 10);

  /// Maximum duration for voice recognition to produce a result.
  static const Duration voiceRecognition = Duration(seconds: 15);
}

/// Throttling and interval constants.
class VoiceScreenIntervals {
  const VoiceScreenIntervals._();

  /// Minimum time between consecutive interactions.
  static const Duration minimumInteractionInterval = Duration(milliseconds: 500);

  /// Duration after which a result is considered stale.
  static const Duration staleResultThreshold = Duration(seconds: 5);
}

/// Session and concurrency limits.
class VoiceScreenLimits {
  const VoiceScreenLimits._();

  /// Maximum number of concurrent interactions allowed.
  /// Only one interaction may be active at a time; any additional
  /// attempt returns [VoiceScreenPhase.concurrentConflict].
  static const int maxConcurrentInteractions = 1;
}

/// Default configuration values for VoiceScreen sessions.
class VoiceScreenDefaults {
  const VoiceScreenDefaults._();

  /// Default locale for voice recognition.
  static const String locale = 'ku';

  /// Default search query target type when none is specified.
  static const String defaultTargetType = 'element';

  /// Minimum confidence threshold for search results.
  static const double minConfidence = 0.3;

  /// Maximum number of search results to return.
  static const int maxResults = 10;
}
