/// reliability_config.dart
/// AURA Assistant – Step 27: API Reliability & Cost Optimization
///
/// Domain model for API reliability configuration.
library;

/// Retry strategy type.
enum RetryStrategy {
  exponentialBackoff,
  fixedInterval,
  immediate,
  none,
  unknown,
  ;

  bool get isRetryable => this == exponentialBackoff || this == fixedInterval || this == immediate;
  bool get isNone => this == none || this == unknown;
}

/// Circuit breaker state.
enum CircuitBreakerState {
  closed,
  open,
  halfOpen,
  unknown,
  ;

  bool get allowsRequests => this == closed || this == halfOpen;
  bool get isDenied => this == open || this == unknown;
}

/// Reliability verdict for an API call.
enum ReliabilityVerdict {
  allowed,
  throttled,
  circuitOpen,
  budgetExceeded,
  rateLimited,
  unknown,
  ;

  bool get isAllowed => this == allowed;
  bool get isDenied => this != allowed;
}

/// Domain model for reliability configuration.
class ReliabilityConfig {
  final String configId;
  final String apiName;
  final int maxRetries;
  final int baseDelayMs;
  final int maxDelayMs;
  final double backoffMultiplier;
  final RetryStrategy retryStrategy;
  final int circuitBreakerThreshold;
  final int circuitBreakerResetMs;
  final CircuitBreakerState circuitBreakerState;
  final int rateLimitPerMinute;
  final int currentRateCount;
  final double timeoutMultiplier;
  final ReliabilityVerdict verdict;

  const ReliabilityConfig({
    required this.configId,
    required this.apiName,
    this.maxRetries = 3,
    this.baseDelayMs = 1000,
    this.maxDelayMs = 30000,
    this.backoffMultiplier = 2.0,
    this.retryStrategy = RetryStrategy.exponentialBackoff,
    this.circuitBreakerThreshold = 5,
    this.circuitBreakerResetMs = 60000,
    this.circuitBreakerState = CircuitBreakerState.closed,
    this.rateLimitPerMinute = 60,
    this.currentRateCount = 0,
    this.timeoutMultiplier = 1.5,
    this.verdict = ReliabilityVerdict.unknown,
  });

  factory ReliabilityConfig.unknown() => const ReliabilityConfig(
    configId: '__unknown__',
    apiName: '__unknown__',
    verdict: ReliabilityVerdict.unknown,
    circuitBreakerState: CircuitBreakerState.unknown,
    retryStrategy: RetryStrategy.unknown,
  );

  bool get isUnknown => configId == '__unknown__';
  int get computedDelayMs => (baseDelayMs * pow(backoffMultiplier)).clamp(baseDelayMs, maxDelayMs).toInt();
  double pow(double base) => base * base;
  bool get isRateLimited => currentRateCount >= rateLimitPerMinute;

  ReliabilityConfig copyWith({
    CircuitBreakerState? circuitBreakerState,
    int? currentRateCount,
    ReliabilityVerdict? verdict,
  }) => ReliabilityConfig(
    configId: configId, apiName: apiName,
    maxRetries: maxRetries, baseDelayMs: baseDelayMs,
    maxDelayMs: maxDelayMs, backoffMultiplier: backoffMultiplier,
    retryStrategy: retryStrategy, circuitBreakerThreshold: circuitBreakerThreshold,
    circuitBreakerResetMs: circuitBreakerResetMs,
    circuitBreakerState: circuitBreakerState ?? this.circuitBreakerState,
    rateLimitPerMinute: rateLimitPerMinute,
    currentRateCount: currentRateCount ?? this.currentRateCount,
    timeoutMultiplier: timeoutMultiplier,
    verdict: verdict ?? this.verdict,
  );

  @override
  String toString() => 'ReliabilityConfig($apiName, cb=$circuitBreakerState, verdict=$verdict)';
}
