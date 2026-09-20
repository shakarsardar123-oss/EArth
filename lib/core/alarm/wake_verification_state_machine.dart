import '../../domain/entities/alarm/wake_verification_state.dart';

/// State machine for wake verification flow.
///
/// Valid transitions:
///   idle         → scheduled
///   scheduled    → ringing
///   ringing      → checking, snoozed, stopped
///   checking      → faceDetected, timeout, error
///   faceDetected  → awaitingVoiceConfirmation, timeout, error
///   awaitingVoiceConfirmation → verified, timeout, error
///   verified      → stopped
///   snoozed       → ringing
///   stopped       → idle
///   timeout       → stopped
///   error         → stopped
class WakeVerificationStateMachine {
  WakeVerificationState _state = WakeVerificationState.idle;

  WakeVerificationState get state => _state;

  /// Attempt to transition to [nextState].
  /// Returns true if transition was valid and applied, false otherwise.
  bool transition(WakeVerificationState nextState) {
    if (!_isValidTransition(_state, nextState)) {
      return false;
    }
    _state = nextState;
    return true;
  }

  /// Force-set state (used for error recovery / reset).
  void reset([WakeVerificationState newState = WakeVerificationState.idle]) {
    _state = newState;
  }

  /// Check if transitioning from [from] to [to] is valid.
  static bool _isValidTransition(
      WakeVerificationState from, WakeVerificationState to) {
    const transitions = <WakeVerificationState, Set<WakeVerificationState>>{
      WakeVerificationState.idle: {WakeVerificationState.scheduled},
      WakeVerificationState.scheduled: {WakeVerificationState.ringing},
      WakeVerificationState.ringing: {
        WakeVerificationState.checking,
        WakeVerificationState.snoozed,
        WakeVerificationState.stopped,
      },
      WakeVerificationState.checking: {
        WakeVerificationState.faceDetected,
        WakeVerificationState.timeout,
        WakeVerificationState.error,
      },
      WakeVerificationState.faceDetected: {
        WakeVerificationState.awaitingVoiceConfirmation,
        WakeVerificationState.timeout,
        WakeVerificationState.error,
      },
      WakeVerificationState.awaitingVoiceConfirmation: {
        WakeVerificationState.verified,
        WakeVerificationState.timeout,
        WakeVerificationState.error,
      },
      WakeVerificationState.verified: {WakeVerificationState.stopped},
      WakeVerificationState.snoozed: {WakeVerificationState.ringing},
      WakeVerificationState.stopped: {WakeVerificationState.idle},
      WakeVerificationState.timeout: {WakeVerificationState.stopped},
      WakeVerificationState.error: {WakeVerificationState.stopped},
    };

    return transitions[from]?.contains(to) ?? false;
  }

  /// Whether the alarm is in an active state.
  bool get isActive => _state.isActive;

  /// Whether verification is complete.
  bool get isComplete => _state.isComplete;

  /// Whether camera preview is needed.
  bool get needsCamera => _state.needsCamera;
}
