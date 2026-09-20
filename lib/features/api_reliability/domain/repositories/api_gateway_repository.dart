/// api_gateway_repository.dart
/// AURA Assistant – Step 27: API Reliability & Cost Optimization
///
/// Domain repository contract for API gateway operations.
/// Infrastructure adapters must implement this interface EXACTLY.
/// FAIL-CLOSED: any error → denied, unknown → denied.
library;

import '../models/api_request.dart';
import '../models/api_cost_profile.dart';
import '../models/reliability_config.dart';

/// Result of an API gateway operation.
enum ApiGatewayResult {
  success,
  denied,
  throttled,
  error,
  unknown,
  ;

  bool get isSuccess => this == success;
  bool get isDenied => this != success;
}

/// Abstract repository for API gateway interactions.
/// Infrastructure adapters must implement this interface EXACTLY.
abstract class ApiGatewayRepository {
  /// Send an API request through the gateway.
  /// FAIL-CLOSED: error → denied result.
  Future<ApiGatewayResult> sendRequest(ApiRequest request);

  /// Get the current reliability config for an API.
  /// FAIL-CLOSED: unknown → circuit open, no retry.
  Future<ReliabilityConfig> getReliabilityConfig(String apiName);

  /// Get the current cost profile for an API.
  /// FAIL-CLOSED: unknown → over budget.
  Future<ApiCostProfile> getCostProfile(String apiName);

  /// Record a successful request.
  Future<void> recordSuccess(String apiName, String requestId);

  /// Record a failed request.
  Future<void> recordFailure(String apiName, String requestId);

  /// Record cost for a request.
  Future<void> recordCost(String apiName, double cost, int tokens);

  /// Reset the circuit breaker for an API.
  Future<void> resetCircuitBreaker(String apiName);

  /// Get all available APIs for a capability.
  Future<List<String>> getAvailableApis(String capability);

  /// Check if the gateway is available.
  bool get isAvailable;
}
