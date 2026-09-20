/// device_integration_failure.dart
///
/// Typed failure for the `device_integration` feature.
///
/// RECOVERED in P1-RECOVERY step R2 from the behaviour pinned by
/// `test/features/device_integration/device_integration_failure_test.dart`.
library;

import '../../../../core/errors/failures.dart';
import '../entities/device_action.dart';

/// The pipeline stage a failure originated from.
///
/// The phase is what lets the UI explain *why* an action stopped: a permission
/// problem is recoverable by prompting, a security refusal never is.
enum DeviceIntegrationFailurePhase {
  /// The action itself was structurally incomplete.
  validation,

  /// A required device permission was missing.
  permission,

  /// Policy refused the action.
  security,

  /// The platform failed to perform the action.
  execution,

  /// The action ran but its effect could not be confirmed.
  verification,

  /// The on-screen target could not be located.
  targetResolution,

  /// The action was cancelled or the feature was inactive.
  cancellation,
}

/// A failure raised anywhere in the device-integration pipeline.
///
/// Equality is based on [phase] and [message] only. [action] and [cause] are
/// diagnostic context: two failures describing the same problem stay equal even
/// when they carry different attachments.
class DeviceIntegrationFailure extends Failure {
  const DeviceIntegrationFailure({
    required this.phase,
    required super.message,
    this.action,
    this.cause,
  });

  /// The action was structurally invalid.
  const DeviceIntegrationFailure.validation(
    String message, {
    DeviceAction? action,
    DeviceIntegrationFailure? cause,
  }) : this(
          phase: DeviceIntegrationFailurePhase.validation,
          message: message,
          action: action,
          cause: cause,
        );

  /// A required permission was not granted.
  const DeviceIntegrationFailure.permission(
    String message, {
    DeviceAction? action,
    DeviceIntegrationFailure? cause,
  }) : this(
          phase: DeviceIntegrationFailurePhase.permission,
          message: message,
          action: action,
          cause: cause,
        );

  /// Policy refused the action.
  const DeviceIntegrationFailure.security(
    String message, {
    DeviceAction? action,
    DeviceIntegrationFailure? cause,
  }) : this(
          phase: DeviceIntegrationFailurePhase.security,
          message: message,
          action: action,
          cause: cause,
        );

  /// The platform could not perform the action.
  const DeviceIntegrationFailure.execution(
    String message, {
    DeviceAction? action,
    DeviceIntegrationFailure? cause,
  }) : this(
          phase: DeviceIntegrationFailurePhase.execution,
          message: message,
          action: action,
          cause: cause,
        );

  /// The effect of the action could not be confirmed.
  const DeviceIntegrationFailure.verification(
    String message, {
    DeviceAction? action,
    DeviceIntegrationFailure? cause,
  }) : this(
          phase: DeviceIntegrationFailurePhase.verification,
          message: message,
          action: action,
          cause: cause,
        );

  /// The target could not be found on screen.
  const DeviceIntegrationFailure.targetResolution(
    String message, {
    DeviceAction? action,
    DeviceIntegrationFailure? cause,
  }) : this(
          phase: DeviceIntegrationFailurePhase.targetResolution,
          message: message,
          action: action,
          cause: cause,
        );

  /// The action was cancelled, or the feature was not active.
  const DeviceIntegrationFailure.cancellation(
    String message, {
    DeviceAction? action,
    DeviceIntegrationFailure? cause,
  }) : this(
          phase: DeviceIntegrationFailurePhase.cancellation,
          message: message,
          action: action,
          cause: cause,
        );

  /// Where in the pipeline the failure happened.
  final DeviceIntegrationFailurePhase phase;

  /// The action being processed, when known.
  final DeviceAction? action;

  /// The underlying error or exception, when there was one.
  ///
  /// Typed as [DeviceIntegrationFailure?] because the most common inner
  /// failure is another pipeline failure; callers that need a broader type
  /// can check at runtime.
  final DeviceIntegrationFailure? cause;

  @override
  bool operator ==(Object other) =>
      other is DeviceIntegrationFailure &&
      other.phase == phase &&
      other.message == message;

  @override
  int get hashCode => Object.hash(phase, message);

  @override
  String toString() => 'DeviceIntegrationFailure(${phase.name}: $message)';
}
