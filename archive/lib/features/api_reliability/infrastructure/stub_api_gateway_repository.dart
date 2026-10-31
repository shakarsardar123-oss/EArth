/// stub_api_gateway_repository.dart
/// AURA Assistant – Step 27: API Reliability
///
/// FAIL-CLOSED stub: all requests denied, circuit breaker closed.
library;

import '../domain/models/api_cost_profile.dart';
import '../domain/models/api_request.dart';
import '../domain/models/reliability_config.dart';
import '../domain/repositories/api_gateway_repository.dart';

class StubApiGatewayRepository implements ApiGatewayRepository {
  @override
  bool get isAvailable => false;

  @override
  Future<ApiGatewayResult> sendRequest(ApiRequest req) async =>
      ApiGatewayResult.denied;

  @override
  Future<ReliabilityConfig> getReliabilityConfig(String apiName) async =>
      ReliabilityConfig.denied;

  @override
  Future<ApiCostProfile> getCostProfile(String apiName) async =>
      ApiCostProfile.denied;

  @override
  Future<void> recordSuccess(String apiName, String reqId) async {}

  @override
  Future<void> recordFailure(String apiName, String reqId) async {}

  @override
  Future<void> recordCost(String apiName, double cost, int tokens) async {}

  @override
  Future<void> resetCircuitBreaker(String apiName) async {}

  @override
  Future<List<String>> getAvailableApis(String capability) async => [];
}
