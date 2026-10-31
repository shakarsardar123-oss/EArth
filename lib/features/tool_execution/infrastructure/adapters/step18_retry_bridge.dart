/// step18_retry_bridge.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Bridge between Step 22 (Tool Execution) and Step 18 (Agent Recovery).
///
/// Adapts Step 18's RetryPolicy, RecoveryStrategy, and RecoveryState
/// for use in Step 22's tool execution retry loop.
///
/// Step 18 API:
///   RetryPolicy: maxRetriesPerStep=3, maxTotalRetries=10,
///               ExponentialBackoffConfig, isRetryable(RecoveryFailurePhase),
///               canRetry, incrementStepRetry(), cancel()
///   RecoveryStrategy: 10 values (retry, fallback, skip, escalate, etc.)
///   RecoveryState: 11 phases
///
/// FAIL CLOSED: any retry that cannot be verified as safe is denied.
library;

/// Bridge for Step 18's ExponentialBackoffConfig.
class ExponentialBackoffConfigBridge {
  final int baseDelayMs;
  final int maxDelayMs;
  final double multiplier;
  final double jitterFactor;

  const ExponentialBackoffConfigBridge({
    this.baseDelayMs = 1000,
    this.maxDelayMs = 30000,
    this.multiplier = 2.0,
    this.jitterFactor = 0.1,
  });
}

/// Bridge for Step 18's RetryPolicy.
///
/// Mirrors: maxRetriesPerStep=3, maxTotalRetries=10,
/// ExponentialBackoffConfig, isRetryable(), canRetry, incrementStepRetry(), cancel().
class RetryPolicyBridge {
  final int maxRetriesPerStep;
  final int maxTotalRetries;
  final ExponentialBackoffConfigBridge backoffConfig;
  final Set<RecoveryFailurePhaseBridge> retryablePhases;

  int _stepRetryCount = 0;
  int _totalRetryCount = 0;
  bool _isCancelled = false;

  RetryPolicyBridge({
    this.maxRetriesPerStep = 3,
    this.maxTotalRetries = 10,
    ExponentialBackoffConfigBridge? backoffConfig,
    Set<RecoveryFailurePhaseBridge>? retryablePhases,
  })  : backoffConfig = backoffConfig ?? const ExponentialBackoffConfigBridge(),
        retryablePhases =
            retryablePhases ?? _defaultRetryablePhases;

  /// Whether more retries are possible.
  bool get canRetry =>
      !_isCancelled &&
      _stepRetryCount < maxRetriesPerStep &&
      _totalRetryCount < maxTotalRetries;

  /// Whether the policy has been cancelled.
  bool get isCancelled => _isCancelled;

  /// Current step retry count.
  int get stepRetryCount => _stepRetryCount;

  /// Total retry count across all steps.
  int get totalRetryCount => _totalRetryCount;

  /// Check if a failure phase is retryable.
  bool isRetryable(RecoveryFailurePhaseBridge phase) =>
      retryablePhases.contains(phase);

  /// Increment step retry counter. Returns true if within limits.
  bool incrementStepRetry() {
    if (!canRetry) return false;
    _stepRetryCount++;
    _totalRetryCount++;
    return _stepRetryCount <= maxRetriesPerStep &&
        _totalRetryCount <= maxTotalRetries;
  }

  /// Reset step retry counter (when moving to a new step/tool).
  void resetStepRetry() => _stepRetryCount = 0;

  /// Cancel the retry policy — no more retries will be allowed.
  void cancel() => _isCancelled = true;

  /// Calculate backoff delay for a given attempt.
  int getBackoffDelay(int attempt) {
    if (_isCancelled) return 0;

    var delay = (backoffConfig.baseDelayMs *
        pow(backoffConfig.multiplier, attempt))
        .toInt();

    // Cap at max delay
    if (delay > backoffConfig.maxDelayMs) {
      delay = backoffConfig.maxDelayMs;
    }

    // Add jitter
    if (backoffConfig.jitterFactor > 0) {
      final jitter =
          (delay * backoffConfig.jitterFactor * (1 - 2 * _random.nextDouble()))
              .toInt();
      delay += jitter;
    }

    return delay.clamp(0, backoffConfig.maxDelayMs);
  }

  static final _defaultRetryablePhases =
      <RecoveryFailurePhaseBridge>{
    RecoveryFailurePhaseBridge.executionTimeout,
    RecoveryFailurePhaseBridge.toolUnavailable,
    RecoveryFailurePhaseBridge.networkError,
    RecoveryFailurePhaseBridge.rateLimitExceeded,
    RecoveryFailurePhaseBridge.resourceBusy,
  };

  // Simple random for jitter
  static final _random = _SimpleRandom();
}

/// Bridge for Step 18's RecoveryFailurePhase.
///
/// Maps failure types to determine retry eligibility.
enum RecoveryFailurePhaseBridge {
  // Retryable
  executionTimeout,
  toolUnavailable,
  networkError,
  rateLimitExceeded,
  resourceBusy,
  // Conditionally retryable
  invalidInput,
  permissionDenied,
  // Not retryable
  securityDenial,
  failClosed,
  userCancelled,
  unknownTool,
  ;

  bool get isRetryable =>
      this == executionTimeout ||
      this == toolUnavailable ||
      this == networkError ||
      this == rateLimitExceeded ||
      this == resourceBusy;

  bool get isConditionallyRetryable =>
      this == invalidInput || this == permissionDenied;

  bool get isNotRetryable =>
      this == securityDenial ||
      this == failClosed ||
      this == userCancelled ||
      this == unknownTool;
}

/// Bridge for Step 18's RecoveryStrategy (10 values).
enum RecoveryStrategyBridge {
  retry,
  retryWithBackoff,
  fallbackTool,
  degradedMode,
  skip,
  escalate,
  abort,
  askUser,
  cacheResult,
  waitAndRetry,
  ;

  String get displayName {
    switch (this) {
      case RecoveryStrategyBridge.retry: return 'Retry';
      case RecoveryStrategyBridge.retryWithBackoff: return 'Retry with Backoff';
      case RecoveryStrategyBridge.fallbackTool: return 'Fallback Tool';
      case RecoveryStrategyBridge.degradedMode: return 'Degraded Mode';
      case RecoveryStrategyBridge.skip: return 'Skip';
      case RecoveryStrategyBridge.escalate: return 'Escalate';
      case RecoveryStrategyBridge.abort: return 'Abort';
      case RecoveryStrategyBridge.askUser: return 'Ask User';
      case RecoveryStrategyBridge.cacheResult: return 'Cache Result';
      case RecoveryStrategyBridge.waitAndRetry: return 'Wait and Retry';
    }
  }
}

/// Bridge between Step 22 and Step 18's retry/recovery system.
///
/// Provides retry logic, backoff calculation, failure classification,
/// and recovery strategy selection for tool execution.
class Step18RetryBridge {
  final RetryPolicyBridge _policy;

  Step18RetryBridge({RetryPolicyBridge? policy})
      : _policy = policy ?? RetryPolicyBridge();

  /// Current retry policy.
  RetryPolicyBridge get policy => _policy;

  /// Whether a tool execution can be retried.
  bool canRetry({
    required String toolId,
    required int currentAttempt,
    required int maxRetries,
  }) {
    if (_policy.isCancelled) return false;
    if (currentAttempt > maxRetries) return false;
    if (currentAttempt > _policy.maxRetriesPerStep) return false;
    return _policy.canRetry;
  }

  /// Get exponential backoff delay for the given attempt number.
  int getBackoffDelay(int attempt) => _policy.getBackoffDelay(attempt);

  /// Classify a failure into a recovery phase.
  ///
  /// Maps error codes and messages to Step 18's RecoveryFailurePhase.
  RecoveryFailurePhaseBridge classifyFailure(
    String errorCode,
    String errorMessage,
  ) {
    final code = errorCode.toLowerCase();
    final msg = errorMessage.toLowerCase();

    // Security-related failures — NOT retryable
    if (code.contains('security') || code.contains('denied') ||
        code.contains('fail_closed') || code.contains('failclosed')) {
      return RecoveryFailurePhaseBridge.securityDenial;
    }
    if (code.contains('permission')) {
      return RecoveryFailurePhaseBridge.permissionDenied;
    }

    // User cancellation — NOT retryable
    if (code.contains('cancel') || code.contains('user_cancel')) {
      return RecoveryFailurePhaseBridge.userCancelled;
    }

    // Unknown tool — NOT retryable
    if (code.contains('not_registered') || code.contains('unknown')) {
      return RecoveryFailurePhaseBridge.unknownTool;
    }

    // Input validation
    if (code.contains('invalid_input') || code.contains('validation')) {
      return RecoveryFailurePhaseBridge.invalidInput;
    }

    // Timeout — retryable
    if (code.contains('timeout') || code.contains('timed_out')) {
      return RecoveryFailurePhaseBridge.executionTimeout;
    }

    // Network errors — retryable
    if (code.contains('network') || code.contains('connection') ||
        msg.contains('network') || msg.contains('connection')) {
      return RecoveryFailurePhaseBridge.networkError;
    }

    // Rate limiting — retryable
    if (code.contains('rate_limit') || code.contains('429')) {
      return RecoveryFailurePhaseBridge.rateLimitExceeded;
    }

    // Resource busy — retryable
    if (code.contains('busy') || code.contains('resource')) {
      return RecoveryFailurePhaseBridge.resourceBusy;
    }

    // Tool unavailable — retryable
    if (code.contains('unavailable') || code.contains('not_ready')) {
      return RecoveryFailurePhaseBridge.toolUnavailable;
    }

    // Default: FAIL CLOSED — not retryable
    return RecoveryFailurePhaseBridge.failClosed;
  }

  /// Whether a failure phase is retryable.
  bool isRetryablePhase(RecoveryFailurePhaseBridge phase) =>
      phase.isRetryable;

  /// Select a recovery strategy for a given failure phase.
  RecoveryStrategyBridge selectStrategy(
    RecoveryFailurePhaseBridge phase, {
    int attemptCount = 0,
  }) {
    switch (phase) {
      case RecoveryFailurePhaseBridge.executionTimeout:
        return attemptCount < 2
            ? RecoveryStrategyBridge.retryWithBackoff
            : RecoveryStrategyBridge.fallbackTool;

      case RecoveryFailurePhaseBridge.toolUnavailable:
        return attemptCount < 2
            ? RecoveryStrategyBridge.waitAndRetry
            : RecoveryStrategyBridge.fallbackTool;

      case RecoveryFailurePhaseBridge.networkError:
        return RecoveryStrategyBridge.retryWithBackoff;

      case RecoveryFailurePhaseBridge.rateLimitExceeded:
        return RecoveryStrategyBridge.waitAndRetry;

      case RecoveryFailurePhaseBridge.resourceBusy:
        return RecoveryStrategyBridge.retryWithBackoff;

      case RecoveryFailurePhaseBridge.invalidInput:
        return RecoveryStrategyBridge.askUser;

      case RecoveryFailurePhaseBridge.permissionDenied:
        return RecoveryStrategyBridge.askUser;

      // NOT retryable — terminal strategies
      case RecoveryFailurePhaseBridge.securityDenial:
        return RecoveryStrategyBridge.abort;

      case RecoveryFailurePhaseBridge.failClosed:
        return RecoveryStrategyBridge.abort;

      case RecoveryFailurePhaseBridge.userCancelled:
        return RecoveryStrategyBridge.skip;

      case RecoveryFailurePhaseBridge.unknownTool:
        return RecoveryStrategyBridge.escalate;
    }
  }

  /// Record a retry attempt in the policy.
  bool recordRetryAttempt() => _policy.incrementStepRetry();

  /// Cancel the retry policy.
  void cancelRetries() => _policy.cancel();

  /// Reset step retry counter (when switching to a different tool).
  void resetStepRetries() => _policy.resetStepRetry();
}

/// Minimal random number generator for jitter.
class _SimpleRandom {
  int _seed = 42;

  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }
}

/// Power function for backoff calculation.
double pow(double base, int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}
