/// State machine states for wake verification.
///
/// Transitions:
///   idle → scheduled → ringing → checking →
///     faceDetected → awaitingVoiceConfirmation → verified → stopped
///   Any state → snoozed (user snooze, restarts from ringing after snooze)
///   ringing/checking/awaitingVoiceConfirmation → timeout
///   Any state → error
enum WakeVerificationState {
  /// No alarm active.
  idle,

  /// Alarm is scheduled but not yet ringing.
  scheduled,

  /// Alarm is ringing, waiting for user interaction.
  ringing,

  /// Verification checks are in progress.
  checking,

  /// Face has been detected by the camera.
  faceDetected,

  /// Face confirmed, waiting for voice command.
  awaitingVoiceConfirmation,

  /// User has successfully completed verification.
  verified,

  /// User snoozed the alarm.
  snoozed,

  /// Alarm fully stopped (dismissed after verify or without verification).
  stopped,

  /// Verification timed out.
  timeout,

  /// An error occurred during verification.
  error,
}

/// Extension for state display helpers.
extension WakeVerificationStateX on WakeVerificationState {
  /// Whether the alarm is actively ringing or being verified.
  bool get isActive =>
      this == WakeVerificationState.ringing ||
      this == WakeVerificationState.checking ||
      this == WakeVerificationState.faceDetected ||
      this == WakeVerificationState.awaitingVoiceConfirmation;

  /// Whether the verification is complete (success or failure).
  bool get isComplete =>
      this == WakeVerificationState.verified ||
      this == WakeVerificationState.stopped ||
      this == WakeVerificationState.timeout ||
      this == WakeVerificationState.error;

  /// Whether the alarm needs the camera preview.
  bool get needsCamera =>
      this == WakeVerificationState.checking ||
      this == WakeVerificationState.faceDetected ||
      this == WakeVerificationState.awaitingVoiceConfirmation;
}
