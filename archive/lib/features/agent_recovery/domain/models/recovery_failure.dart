/// recovery_failure.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Structured failure type for the agent recovery feature.
/// Follows the DeviceIntegrationFailure pattern:
///   - const constructor + factory constructors per phase
///   - action/cause fields (dynamic action, Object? cause)
///   - equality on phase+message only
///
/// Kurdish-first, local-first, privacy-conscious.
library;

import '../../../../core/errors/result.dart';
import 'recovery_failure_phase.dart';

/// A structured failure from the agent recovery pipeline.
///
/// Each failure carries:
/// - [phase]: which phase of recovery failed
/// - [message]: human-readable error description
/// - [action]: the action/step that was being processed (dynamic)
/// - [cause]: optional original exception or error object
///
/// Equality is based on [phase] and [message] only, matching
/// the DeviceIntegrationFailure pattern.
class RecoveryFailure {
  /// Which phase of the recovery pipeline failed.
  final RecoveryFailurePhase phase;

  /// Human-readable error message.
  final String message;

  /// The action or step that was being processed when failure occurred.
  /// Null if the failure happened before an action was identified.
  final dynamic action;

  /// Optional original cause (exception or error object).
  final Object? cause;

  const RecoveryFailure({
    required this.phase,
    required this.message,
    this.action,
    this.cause,
  });

  // ─── Factory constructors per phase ───────────────────────────────

  /// Convenience constructor for tool-failure phase.
  factory RecoveryFailure.toolFailure(
    String message, {
    dynamic action,
    Object? cause,
  }) =>
      RecoveryFailure(
        phase: RecoveryFailurePhase.toolFailure,
        message: message,
        action: action,
        cause: cause,
      );

  /// Convenience constructor for permission-failure phase.
  factory RecoveryFailure.permissionFailure(
    String message, {
    dynamic action,
    Object? cause,
  }) =>
      RecoveryFailure(
        phase: RecoveryFailurePhase.permissionFailure,
        message: message,
        action: action,
        cause: cause,
      );

  /// Convenience constructor for timeout phase.
  factory RecoveryFailure.timeout(
    String message, {
    dynamic action,
    Object? cause,
  }) =>
      RecoveryFailure(
        phase: RecoveryFailurePhase.timeout,
        message: message,
        action: action,
        cause: cause,
      );

  /// Convenience constructor for cancellation phase.
  factory RecoveryFailure.cancellation(
    String message, {
    dynamic action,
    Object? cause,
  }) =>
      RecoveryFailure(
        phase: RecoveryFailurePhase.cancellation,
        message: message,
        action: action,
        cause: cause,
      );

  /// Convenience constructor for invalid-parameters phase.
  factory RecoveryFailure.invalidParameters(
    String message, {
    dynamic action,
    Object? cause,
  }) =>
      RecoveryFailure(
        phase: RecoveryFailurePhase.invalidParameters,
        message: message,
        action: action,
        cause: cause,
      );

  /// Convenience constructor for target-not-found phase.
  factory RecoveryFailure.targetNotFound(
    String message, {
    dynamic action,
    Object? cause,
  }) =>
      RecoveryFailure(
        phase: RecoveryFailurePhase.targetNotFound,
        message: message,
        action: action,
        cause: cause,
      );

  /// Convenience constructor for screen-state-changed phase.
  factory RecoveryFailure.screenStateChanged(
    String message, {
    dynamic action,
    Object? cause,
  }) =>
      RecoveryFailure(
        phase: RecoveryFailurePhase.screenStateChanged,
        message: message,
        action: action,
        cause: cause,
      );

  /// Convenience constructor for verification-failure phase.
  factory RecoveryFailure.verificationFailure(
    String message, {
    dynamic action,
    Object? cause,
  }) =>
      RecoveryFailure(
        phase: RecoveryFailurePhase.verificationFailure,
        message: message,
        action: action,
        cause: cause,
      );

  /// Convenience constructor for network-failure phase.
  factory RecoveryFailure.networkFailure(
    String message, {
    dynamic action,
    Object? cause,
  }) =>
      RecoveryFailure(
        phase: RecoveryFailurePhase.networkFailure,
        message: message,
        action: action,
        cause: cause,
      );

  /// Convenience constructor for unsupported-action phase.
  factory RecoveryFailure.unsupportedAction(
    String message, {
    dynamic action,
    Object? cause,
  }) =>
      RecoveryFailure(
        phase: RecoveryFailurePhase.unsupportedAction,
        message: message,
        action: action,
        cause: cause,
      );

  /// Convenience constructor for unknown phase.
  factory RecoveryFailure.unknown(
    String message, {
    dynamic action,
    Object? cause,
  }) =>
      RecoveryFailure(
        phase: RecoveryFailurePhase.unknown,
        message: message,
        action: action,
        cause: cause,
      );

  // ─── Equality (phase + message only) ───────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecoveryFailure &&
          phase == other.phase &&
          message == other.message;

  @override
  int get hashCode => Object.hash(phase, message);

  @override
  String toString() =>
      'RecoveryFailure(phase: $phase, message: $message)';
}

/// Type alias for results in the agent recovery feature.
typedef RecoveryResult<T> = Result<T, RecoveryFailure>;
