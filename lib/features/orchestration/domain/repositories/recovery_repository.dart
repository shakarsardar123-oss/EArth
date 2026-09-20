/// Step 23 — Recovery Repository Interface
///
/// Contract for the Step 18 Recovery adapter.
/// Do not create a second recovery engine — delegate to existing Step 18.
///
/// Key contract: recovery_tool uses context.retryAttempt (not recoveryAttempt/currentRetry).

abstract class RecoveryRepository {
  /// Classify a failure and determine a recovery strategy.
  /// Returns RecoveryStrategy. Default/unknown = abort (FAIL-CLOSED).
  Future<RecoveryStrategy> classifyAndStrategize({
    required String failureType,
    required String errorMessage,
    required int retryAttempt,
  });

  /// Execute the recovery strategy.
  /// Returns true if recovery succeeded and retry is viable.
  Future<bool> executeStrategy(RecoveryStrategy strategy);

  /// Whether the recovery subsystem is available.
  Future<bool> isAvailable();
}

/// Recovery strategy — FAIL-CLOSED: default is abort.
enum RecoveryAction {
  retry, // Retry same execution
  modify, // Modify parameters and retry
  recapture, // Re-capture user intent
  reunderstand, // Re-understand the request
  replan, // Re-plan from scratch
  abort, // Give up (FAIL-CLOSED default)
  ;
}

class RecoveryStrategy {
  final RecoveryAction action;
  final String? modifiedParameters;
  final int maxRetries;
  final int currentAttempt;
  final String? reason;

  const RecoveryStrategy({
    this.action = RecoveryAction.abort,
    this.modifiedParameters,
    this.maxRetries = 3,
    this.currentAttempt = 0,
    this.reason,
  });

  factory RecoveryStrategy.abort({String? reason}) =>
      RecoveryStrategy(action: RecoveryAction.abort, reason: reason);

  factory RecoveryStrategy.retry({int currentAttempt = 0, int maxRetries = 3}) =>
      RecoveryStrategy(action: RecoveryAction.retry, currentAttempt: currentAttempt, maxRetries: maxRetries);

  bool get canRetry => currentAttempt < maxRetries && action != RecoveryAction.abort;
}
