/// api_reliability_orchestrator.dart
/// AURA Assistant – Step 27: API Reliability & Cost Optimization
///
/// Orchestrates ApiReliabilityService + ApiGatewayRepository.
/// FAIL-CLOSED: circuit breaker closed → deny, budget exceeded → deny.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/api_cost_profile.dart';
import '../domain/models/api_request.dart';
import '../domain/models/reliability_config.dart';
import '../domain/repositories/api_gateway_repository.dart';
import '../domain/services/api_reliability_service.dart';
import 'providers.dart';

class ApiReliabilityOrchestrator {
  final ApiReliabilityService _reliabilityService;
  final ApiGatewayRepository _gatewayRepository;

  ApiReliabilityOrchestrator({
    required ApiReliabilityService reliabilityService,
    required ApiGatewayRepository gatewayRepository,
  })  : _reliabilityService = reliabilityService,
        _gatewayRepository = gatewayRepository;

  /// Evaluate and send an API request.
  /// FAIL-CLOSED: circuit breaker closed or budget exceeded → deny.
  Future<ApiGatewayResult> sendRequest(ApiRequest request) async {
    if (!_gatewayRepository.isAvailable) return ApiGatewayResult.denied;
    final verdict = await _reliabilityService.evaluateRequest(request);
    if (verdict.isDenied) return ApiGatewayResult.denied;
    return _gatewayRepository.sendRequest(request);
  }

  /// Get reliability config for an API.
  Future<ReliabilityConfig> getReliabilityConfig(String apiName) async {
    return _reliabilityService.getReliabilityConfig(apiName);
  }

  /// Get cost profile for an API.
  Future<ApiCostProfile> getCostProfile(String apiName) async {
    return _reliabilityService.getCostProfile(apiName);
  }

  /// Record a successful API call.
  Future<void> recordSuccess(ApiRequest request) async {
    await _reliabilityService.recordSuccess(request);
  }

  /// Record a failed API call.
  Future<void> recordFailure(ApiRequest request) async {
    await _reliabilityService.recordFailure(request);
  }

  /// Record API cost.
  Future<void> recordCost(String apiName, double cost, int tokens) async {
    await _reliabilityService.recordCost(apiName, cost, tokens);
  }

  /// Calculate retry delay in milliseconds.
  int calculateRetryDelay(String apiName, int attempt) {
    return _reliabilityService.calculateRetryDelay(apiName, attempt);
  }

  /// Check if circuit breaker is closed for an API.
  Future<bool> isCircuitBreakerClosed(String apiName) async {
    return _reliabilityService.isCircuitBreakerClosed(apiName);
  }

  /// Check if an API is within budget.
  Future<bool> isWithinBudget(String apiName, double estimatedCost) async {
    return _reliabilityService.isWithinBudget(apiName, estimatedCost);
  }

  /// Check if an API is within rate limit.
  Future<bool> isWithinRateLimit(String apiName) async {
    return _reliabilityService.isWithinRateLimit(apiName);
  }

  /// Select the optimal API for a given capability.
  Future<String?> selectOptimalApi(String capability) async {
    return _reliabilityService.selectOptimalApi(capability);
  }

  /// Reset circuit breaker for an API.
  Future<void> resetCircuitBreaker(String apiName) async {
    await _reliabilityService.resetCircuitBreaker(apiName);
  }
}

final apiReliabilityOrchestratorProvider = Provider<ApiReliabilityOrchestrator>((ref) {
  return ApiReliabilityOrchestrator(
    reliabilityService: ref.watch(apiReliabilityServiceProvider),
    gatewayRepository: ref.watch(apiGatewayRepositoryProvider),
  );
});
