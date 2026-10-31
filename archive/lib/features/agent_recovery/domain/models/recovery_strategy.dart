/// recovery_strategy.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Enum of recovery strategies the replanning engine can choose.
/// 10 strategies covering the full spectrum from simple retry
/// to safe abort.
///
/// Kurdish-first, local-first, privacy-conscious.
library;

/// Strategies the recovery system can employ when a step fails.
///
/// Ordered roughly from least disruptive to most disruptive.
enum RecoveryStrategy {
  /// Retry the exact same step with the same parameters.
  retrySame,

  /// Retry with modified parameters (e.g. different coordinates).
  retryModified,

  /// Re-capture the screen and try again with fresh context.
  recaptureScreen,

  /// Re-understand the screen state before acting.
  reunderstandScreen,

  /// Re-search for the target element on screen.
  researchTarget,

  /// Replan the entire remaining sequence from this point.
  replan,

  /// Request the user to grant a missing permission.
  requestPermission,

  /// Wait a period then retry (for transient failures).
  waitAndRetry,

  /// Skip the failed step and continue with the plan.
  skipStep,

  /// Abort execution safely — no more retries.
  abortSafely,
}
