/// api_reliability_service.dart
/// AURA Assistant – Step 27: API Reliability & Cost Optimization
///
/// Domain service for API reliability management (circuit breaker,
/// rate limiting, budget enforcement, retry logic).
/// FAIL-CLOSED: unknown → DENY, error → DENY, budget exceeded → DENY,
/// circuit open → DENY, rate limited → DENY.
library;

import '../models/api_request.dart';
import '../models/api_cost_profile.dart';
import '../models/reliability_config.dart';

/// Verdict for whether an API call is permitted.
enum ApiReliabilityVerdict {
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

/// Domain service governing API reliability and cost.
abstract class ApiReliabilityService {
  /// Evaluate whether an API request is permitted.
  /// Checks: circuit breaker, rate limit, budget.
  /// FAIL-CLOSED: any check unknown/error → denied.
  Future<ApiReliabilityVerdict> evaluateRequest(ApiRequest request);

  /// Get the current reliability configuration for an API.
  /// FAIL-CLOSED: unknown → circuit open, no retry.
  Future<ReliabilityConfig> getReliabilityConfig(String apiName);

  /// Get the current cost profile for an API.
  /// FAIL-CLOSED: unknown → over budget.
  Future<ApiCostProfile> getCostProfile(String apiName);

  /// Record a successful API call for metrics.
  Future<void> recordSuccess(ApiRequest request);

  /// Record a failed API call for circuit breaker / retry tracking.
  Future<void> recordFailure(ApiRequest request);

  /// Record the cost of an API call for budget tracking.
  Future<void> recordCost(String apiName, double cost, int tokens);

  /// Calculate the retry delay for the given attempt.
  /// FAIL-CLOSED: unknown config → maxDelayMs.
  int calculateRetryDelay(String apiName, int attempt);

  /// Check if the circuit breaker allows a request.
  /// FAIL-CLOSED: unknown → open (denied).
  Future<bool> isCircuitBreakerClosed(String apiName);

  /// Check if budget allows a request.
  /// FAIL-CLOSED: unknown → exceeded (denied).
  Future<bool> isWithinBudget(String apiName, double estimatedCost);

  /// Check if rate limit allows a request.
  /// FAIL-CLOSED: unknown → rate limited (denied).
  Future<bool> isWithinRateLimit(String apiName);

  /// Get the optimal API to use for a given capability, considering
  /// reliability and cost.
  /// FAIL-CLOSED: no viable API → null.
  Future<String?> selectOptimalApi(String capability);

  /// Reset the circuit breaker for an API (admin/debug only).
  /// FAIL-CLOSED: unknown API → no-op.
  Future<void> resetCircuitBreaker(String apiName);
}
