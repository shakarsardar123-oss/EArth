/// device_integration_state.dart
///
/// Immutable UI/controller state for the `device_integration` feature.
///
/// RECOVERED in P1-RECOVERY step R2 from the behaviour pinned by
/// `test/features/device_integration/device_integration_state_test.dart`.
library;

import '../entities/device_action.dart';
import 'device_integration_failure.dart';

/// Where the pipeline currently is for the action being handled.
enum DeviceIntegrationProcessingState {
  /// Nothing in flight.
  idle,

  /// Checking the action against structure, policy and permissions.
  validating,

  /// Waiting for the user to answer a permission prompt.
  awaitingPermission,

  /// The platform is performing the action.
  executing,

  /// Confirming the action had the intended effect.
  verifying,

  /// The last action completed and was confirmed.
  success,

  /// The last action failed.
  failure,
}

/// Immutable snapshot of the feature's state.
class DeviceIntegrationState {
  const DeviceIntegrationState({
    this.processingState = DeviceIntegrationProcessingState.idle,
    this.isActive = false,
    this.actionQueue = const <DeviceAction>[],
    this.currentAction,
    this.lastCompletedAction,
    this.lastError,
    this.warning,
    this.successCount = 0,
    this.failureCount = 0,
    this.securityRejectionCount = 0,
  });

  /// Current pipeline stage.
  final DeviceIntegrationProcessingState processingState;

  /// Whether the feature has been activated by the user.
  final bool isActive;

  /// Actions waiting to be processed, in order.
  final List<DeviceAction> actionQueue;

  /// The action being processed right now, if any.
  final DeviceAction? currentAction;

  /// The most recently finished action, if any.
  final DeviceAction? lastCompletedAction;

  /// The most recent failure, if any.
  final DeviceIntegrationFailure? lastError;

  /// A non-fatal message for the user, if any.
  final String? warning;

  /// Number of actions that completed successfully.
  final int successCount;

  /// Number of actions that failed.
  final int failureCount;

  /// Number of actions refused by security policy.
  final int securityRejectionCount;

  /// Whether an action is currently being handled.
  ///
  /// `success` and `failure` are terminal reports, not work in progress, so they
  /// are not counted as processing.
  bool get isProcessing =>
      processingState == DeviceIntegrationProcessingState.validating ||
      processingState == DeviceIntegrationProcessingState.awaitingPermission ||
      processingState == DeviceIntegrationProcessingState.executing ||
      processingState == DeviceIntegrationProcessingState.verifying;

  /// Whether the pipeline is at rest with nothing reported.
  bool get isIdle => processingState == DeviceIntegrationProcessingState.idle;

  /// Total number of actions that reached a terminal outcome.
  int get totalProcessed => successCount + failureCount;

  /// Returns a copy with the given fields replaced.
  ///
  /// Nullable fields cannot be cleared by passing `null` (that is
  /// indistinguishable from "not supplied"), so each has an explicit
  /// `clearXxx` flag.
  DeviceIntegrationState copyWith({
    DeviceIntegrationProcessingState? processingState,
    bool? isActive,
    List<DeviceAction>? actionQueue,
    DeviceAction? currentAction,
    DeviceAction? lastCompletedAction,
    DeviceIntegrationFailure? lastError,
    String? warning,
    int? successCount,
    int? failureCount,
    int? securityRejectionCount,
    bool clearCurrentAction = false,
    bool clearLastCompletedAction = false,
    bool clearError = false,
    bool clearWarning = false,
  }) {
    return DeviceIntegrationState(
      processingState: processingState ?? this.processingState,
      isActive: isActive ?? this.isActive,
      actionQueue: actionQueue ?? this.actionQueue,
      currentAction:
          clearCurrentAction ? null : (currentAction ?? this.currentAction),
      lastCompletedAction: clearLastCompletedAction
          ? null
          : (lastCompletedAction ?? this.lastCompletedAction),
      lastError: clearError ? null : (lastError ?? this.lastError),
      warning: clearWarning ? null : (warning ?? this.warning),
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      securityRejectionCount:
          securityRejectionCount ?? this.securityRejectionCount,
    );
  }

  @override
  String toString() => 'DeviceIntegrationState(${processingState.name}, '
      'queue: ${actionQueue.length}, ok: $successCount, fail: $failureCount)';
}
