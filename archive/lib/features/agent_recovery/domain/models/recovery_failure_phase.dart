/// recovery_failure_phase.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Enum of phases where recovery failures can occur.
/// 11 phases covering the full agent recovery pipeline.
///
/// Kurdish-first, local-first, privacy-conscious.
library;

/// Phases in the agent recovery pipeline where failures can occur.
///
/// These map to specific failure categories that the recovery
/// system must classify, handle, and potentially retry.
enum RecoveryFailurePhase {
  /// Agent tool invocation failed (e.g. accessibility service error).
  toolFailure,

  /// Required permission was not granted (e.g. overlay, accessibility).
  permissionFailure,

  /// Operation timed out (e.g. screen capture, action execution).
  timeout,

  /// Operation was cancelled by user or system.
  cancellation,

  /// Invalid or missing parameters in the action request.
  invalidParameters,

  /// Target element was not found on screen.
  targetNotFound,

  /// Screen state changed unexpectedly during execution.
  screenStateChanged,

  /// Post-action verification failed (action succeeded, result wrong).
  verificationFailure,

  /// Network-related failure (offline, unreachable).
  networkFailure,

  /// Action is not supported on this device/configuration.
  unsupportedAction,

  /// Unknown/unclassified failure.
  unknown,
}
