/// Policy controlling how a step or plan retries on failure.
class RetryPolicy {
  const RetryPolicy({
    this.maxRetries = 3,
    this.retryDelayMs = 1000,
    this.backoffMultiplier = 2.0,
    this.retryOn = const [
      FailureClassification.temporary,
      FailureClassification.timeout,
      FailureClassification.transient,
    ],
  });

  /// Maximum number of retry attempts (0 = no retry).
  final int maxRetries;

  /// Initial delay between retries in milliseconds.
  final int retryDelayMs;

  /// Exponential backoff multiplier.
  final double backoffMultiplier;

  /// Which failure classifications are eligible for retry.
  final List<FailureClassification> retryOn;

  /// Whether a given failure classification is retryable under this policy.
  bool canRetry(FailureClassification classification) {
    if (maxRetries <= 0) return false;
    return retryOn.contains(classification);
  }

  /// Calculates the delay for the given retry attempt (0-indexed).
  int delayForAttempt(int attempt) {
    final multiplier =
        attempt == 0 ? 1.0 : backoffMultiplier * attempt;
    return (retryDelayMs * multiplier).round();
  }

  @override
  String toString() =>
      'RetryPolicy(max: $maxRetries, delay: ${retryDelayMs}ms)';
}

/// Classification of failures for retry decisions.
enum FailureClassification {
  /// Transient failure — safe to retry (network glitch, etc.).
  temporary,

  /// Arguments were invalid — not retryable without changes.
  validation,

  /// Permission was denied — may need user action.
  permission,

  /// Operation timed out — safe to retry.
  timeout,

  /// Platform doesn't support this operation.
  unsupported,

  /// Resource unavailable — may need alternative approach.
  resource,

  /// Transient failure — alias for temporary.
  transient,

  /// Permanent failure — do not retry.
  permanent;

  bool get isRetryable =>
      this == FailureClassification.temporary ||
      this == FailureClassification.timeout ||
      this == FailureClassification.transient;
}
