/// recovery_repository.dart
/// AURA Assistant – Step 25: Adapter target for Step 18 RecoveryRepository
///
/// Exact signature match from Step 23.
/// This interface MUST be implemented by Step18RecoveryAdapter.
/// FAIL-CLOSED: RecoveryStrategy default action is abort.
library;

/// Recovery action (matches Step 23).
enum RecoveryAction {
  retry,
  replan,
  skip,
  abort,
  ;

  /// FAIL-CLOSED: unknown name → abort.
  static RecoveryAction fromName(String name) {
    return RecoveryAction.values.firstWhere(
      (e) => e.name == name,
      orElse: () => RecoveryAction.abort,
    );
  }
}

/// Recovery strategy (matches Step 23).
class RecoveryStrategy {
  final RecoveryAction action;
  final int maxRetries;
  final int currentRetry;
  final String? message;

  const RecoveryStrategy({
    this.action = RecoveryAction.abort,
    this.maxRetries = 3,
    this.currentRetry = 0,
    this.message,
  });

  /// FAIL-CLOSED: canRetry only true if action is retry AND under max.
  bool get canRetry =>
      action == RecoveryAction.retry && currentRetry < maxRetries;

  /// Whether the strategy allows skipping.
  bool get canSkip => action == RecoveryAction.skip;

  /// Whether the strategy indicates replanning.
  bool get canReplan => action == RecoveryAction.replan;

  /// Whether the strategy indicates abort.
  bool get shouldAbort => action == RecoveryAction.abort;
}

/// Abstract repository matching Step 23's RecoveryRepository.
/// classifyAndStrategize({failureType, errorMessage, retryAttempt}) → RecoveryStrategy
/// executeStrategy(strategy) → bool
/// isAvailable() → bool
abstract class RecoveryRepository {
  Future<RecoveryStrategy> classifyAndStrategize({
    required String failureType,
    required String errorMessage,
    int retryAttempt = 0,
  });
  Future<bool> executeStrategy(RecoveryStrategy strategy);
  bool isAvailable();
}
