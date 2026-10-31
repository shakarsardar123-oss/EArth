/// providers.dart
/// AURA Assistant – Step 27: API Reliability — Riverpod providers
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/repositories/api_gateway_repository.dart';
import '../domain/services/api_reliability_service.dart';

final apiReliabilityServiceProvider = Provider<ApiReliabilityService>((ref) {
  throw UnimplementedError('apiReliabilityServiceProvider must be overridden');
});

final apiGatewayRepositoryProvider = Provider<ApiGatewayRepository>((ref) {
  throw UnimplementedError('apiGatewayRepositoryProvider must be overridden');
});

final circuitBreakerStatusProvider = StateProvider<Map<String, bool>>((ref) => {});

final budgetStatusProvider = StateProvider<Map<String, bool>>((ref) => {});
