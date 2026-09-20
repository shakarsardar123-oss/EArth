/// live_mode_state.dart
/// AURA Assistant – P0 Remediation: Live Mode State Machine
///
/// State machine for continuous Live Mode voice interaction:
/// IDLE → LISTENING → PROCESSING → SPEAKING → LISTENING → ...
/// User STOP at any state → IDLE.
///
/// FAIL-CLOSED: any unknown state → idle, error → auto-stop after retry limit.
/// Kurdish Sorani RTL-first.
library;

/// Live Mode session state — tracks where we are in the continuous cycle.
enum LiveModeState {
  /// Not in a Live session.
  idle,

  /// Microphone is open, listening for user speech.
  listening,

  /// User speech recognized, sending to AgentEngine for processing.
  processing,

  /// Agent response is being spoken via TTS.
  speaking,

  /// Unrecoverable error; session will auto-stop after retry exhaustion.
  error,
  ;

  /// Whether the state represents an active Live session.
  bool get isActive => this == listening || this == processing || this == speaking;

  /// User-readable status text in Kurdish Sorani.
  String get statusText => switch (this) {
    idle => 'ئامادەیە',
    listening => 'گوێگرتن...',
    processing => 'بیرکردنەوە...',
    speaking => 'قسەکردن...',
    error => 'هەڵە',
  };
}

/// Session generation token for concurrency safety.
/// Incremented on each new session start. Callbacks from stale
/// generations are discarded.
class LiveModeSession {
  LiveModeSession({
    required this.sessionId,
    required this.generation,
  });

  final String sessionId;
  final int generation;

  bool isCurrent(int currentGeneration) => generation == currentGeneration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveModeSession &&
          sessionId == other.sessionId &&
          generation == other.generation;

  @override
  int get hashCode => Object.hash(sessionId, generation);
}
