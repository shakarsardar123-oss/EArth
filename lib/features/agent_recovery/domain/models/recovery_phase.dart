/// recovery_phase.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Enum of phases in the recovery state machine.
/// 11 phases tracking the full lifecycle of recovery.
///
/// Kurdish-first, local-first, privacy-conscious.
library;

/// Phases of the agent recovery lifecycle.
///
/// The recovery state machine transitions through these phases
/// as it executes, fails, analyzes, recovers, replans, and
/// either succeeds or aborts.
enum RecoveryPhase {
  /// No recovery operation in progress.
  idle,

  /// Agent step is currently executing.
  executing,

  /// Post-action verification is in progress.
  verifying,

  /// A step has failed; awaiting analysis.
  failed,

  /// Analyzing the failure to determine cause and strategy.
  analyzingFailure,

  /// Applying a recovery strategy to the failed step.
  recovering,

  /// Replanning the remaining steps in the agent plan.
  replanning,

  /// Retrying a step (possibly with modifications).
  retrying,

  /// Recovery completed successfully.
  succeeded,

  /// Recovery aborted — no more attempts allowed.
  aborted,

  /// Recovery cancelled by user or system.
  cancelled,
}
