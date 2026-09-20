/// default_recovery_failure_classifier.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Default implementation of RecoveryFailureClassifier.
/// Maps common exception types and error strings to
/// RecoveryFailurePhase values.
///
/// Clean architecture: Infrastructure layer, implements Domain service.
///
/// Kurdish-first, local-first, privacy-conscious.
library;

import '../domain/models/recovery_failure.dart';
import '../domain/models/recovery_failure_phase.dart';
import '../domain/models/recovery_strategy.dart';
import '../domain/services/recovery_failure_classifier.dart';

/// Default implementation of the failure classifier.
///
/// Uses string matching on error messages and exception type names
/// to classify failures into [RecoveryFailurePhase] values.
class DefaultRecoveryFailureClassifier implements RecoveryFailureClassifier {
  const DefaultRecoveryFailureClassifier();

  @override
  RecoveryFailure classify(
    Object rawError, {
    dynamic action,
  }) {
    final errorString = rawError.toString().toLowerCase();
    final phase = _mapErrorToPhase(rawError, errorString);

    return RecoveryFailure(
      phase: phase,
      message: rawError.toString(),
      action: action,
      cause: rawError is Exception ? rawError : null,
    );
  }

  @override
  RecoveryStrategy defaultStrategyForPhase(RecoveryFailurePhase phase) {
    switch (phase) {
      case RecoveryFailurePhase.toolFailure:
        return RecoveryStrategy.retrySame;
      case RecoveryFailurePhase.permissionFailure:
        return RecoveryStrategy.requestPermission;
      case RecoveryFailurePhase.timeout:
        return RecoveryStrategy.waitAndRetry;
      case RecoveryFailurePhase.cancellation:
        return RecoveryStrategy.abortSafely;
      case RecoveryFailurePhase.invalidParameters:
        return RecoveryStrategy.retryModified;
      case RecoveryFailurePhase.targetNotFound:
        return RecoveryStrategy.researchTarget;
      case RecoveryFailurePhase.screenStateChanged:
        return RecoveryStrategy.recaptureScreen;
      case RecoveryFailurePhase.verificationFailure:
        return RecoveryStrategy.reunderstandScreen;
      case RecoveryFailurePhase.networkFailure:
        return RecoveryStrategy.waitAndRetry;
      case RecoveryFailurePhase.unsupportedAction:
        return RecoveryStrategy.abortSafely;
      case RecoveryFailurePhase.unknown:
        return RecoveryStrategy.retrySame;
    }
  }

  @override
  bool isPhaseRetryable(RecoveryFailurePhase phase) {
    switch (phase) {
      case RecoveryFailurePhase.toolFailure:
      case RecoveryFailurePhase.timeout:
      case RecoveryFailurePhase.screenStateChanged:
      case RecoveryFailurePhase.verificationFailure:
      case RecoveryFailurePhase.networkFailure:
      case RecoveryFailurePhase.targetNotFound:
        return true;
      case RecoveryFailurePhase.permissionFailure:
      case RecoveryFailurePhase.cancellation:
      case RecoveryFailurePhase.invalidParameters:
      case RecoveryFailurePhase.unsupportedAction:
      case RecoveryFailurePhase.unknown:
        return false;
    }
  }

  @override
  String describePhase(RecoveryFailurePhase phase) {
    switch (phase) {
      case RecoveryFailurePhase.toolFailure:
        return 'Agent tool invocation failed';
      case RecoveryFailurePhase.permissionFailure:
        return 'Required permission not granted';
      case RecoveryFailurePhase.timeout:
        return 'Operation timed out';
      case RecoveryFailurePhase.cancellation:
        return 'Operation cancelled';
      case RecoveryFailurePhase.invalidParameters:
        return 'Invalid or missing parameters';
      case RecoveryFailurePhase.targetNotFound:
        return 'Target element not found';
      case RecoveryFailurePhase.screenStateChanged:
        return 'Screen state changed unexpectedly';
      case RecoveryFailurePhase.verificationFailure:
        return 'Post-action verification failed';
      case RecoveryFailurePhase.networkFailure:
        return 'Network failure';
      case RecoveryFailurePhase.unsupportedAction:
        return 'Action not supported';
      case RecoveryFailurePhase.unknown:
        return 'Unknown failure';
    }
  }

  RecoveryFailurePhase _mapErrorToPhase(Object rawError, String errorString) {
    // Check for timeout-related errors
    if (errorString.contains('timeout') ||
        errorString.contains('timed out')) {
      return RecoveryFailurePhase.timeout;
    }

    // Check for permission errors
    if (errorString.contains('permission') ||
        errorString.contains('denied') ||
        errorString.contains('forbidden')) {
      return RecoveryFailurePhase.permissionFailure;
    }

    // Check for cancellation
    if (errorString.contains('cancel') ||
        errorString.contains('aborted')) {
      return RecoveryFailurePhase.cancellation;
    }

    // Check for network errors
    if (errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('connection') ||
        errorString.contains('host')) {
      return RecoveryFailurePhase.networkFailure;
    }

    // Check for target not found
    if (errorString.contains('not found') ||
        errorString.contains('not visible') ||
        errorString.contains('no element')) {
      return RecoveryFailurePhase.targetNotFound;
    }

    // Check for screen state changes
    if (errorString.contains('screen') &&
        (errorString.contains('changed') ||
            errorString.contains('different'))) {
      return RecoveryFailurePhase.screenStateChanged;
    }

    // Check for verification failures
    if (errorString.contains('verification') ||
        errorString.contains('verify') ||
        errorString.contains('unexpected result')) {
      return RecoveryFailurePhase.verificationFailure;
    }

    // Check for invalid parameters
    if (errorString.contains('invalid') ||
        errorString.contains('missing parameter') ||
        errorString.contains('argument')) {
      return RecoveryFailurePhase.invalidParameters;
    }

    // Check for unsupported action
    if (errorString.contains('unsupported') ||
        errorString.contains('not supported')) {
      return RecoveryFailurePhase.unsupportedAction;
    }

    // Default: unknown
    return RecoveryFailurePhase.unknown;
  }
}
