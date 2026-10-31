/// resource_optimization_orchestrator.dart
/// AURA Assistant – Step 27: Battery & Thermal Optimization
///
/// Orchestrates ResourceOptimizationService + SystemResourceRepository.
/// FAIL-CLOSED: unknown → 90% throttle, error → deny feature.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/battery_optimization_profile.dart';
import '../domain/models/resource_state.dart';
import '../domain/repositories/system_resource_repository.dart';
import '../domain/services/resource_optimization_service.dart';
import 'providers.dart';

class ResourceOptimizationOrchestrator {
  final ResourceOptimizationService _optimizationService;
  final SystemResourceRepository _resourceRepository;

  ResourceOptimizationOrchestrator({
    required ResourceOptimizationService optimizationService,
    required SystemResourceRepository resourceRepository,
  })  : _optimizationService = optimizationService,
        _resourceRepository = resourceRepository;

  /// Get current resource state from repository.
  /// FAIL-CLOSED: repo unavailable → unknown critical state.
  Future<ResourceState> getCurrentState() async {
    if (!_resourceRepository.isAvailable) {
      return ResourceState.critical;
    }
    return _resourceRepository.getFullState();
  }

  /// Determine optimal battery profile based on current state.
  BatteryOptimizationProfile determineOptimalProfile(ResourceState state) {
    return _optimizationService.determineOptimalProfile(state);
  }

  /// Apply an optimization profile.
  /// FAIL-CLOSED: service unavailable → deny.
  Future<OptimizationVerdict> applyProfile(BatteryOptimizationProfile profile) async {
    if (!_optimizationService.isAvailable) return OptimizationVerdict.denied;
    return _optimizationService.applyProfile(profile);
  }

  /// Check if a feature is allowed under the given profile.
  bool isFeatureAllowed(String featureId, BatteryOptimizationProfile profile) {
    return _optimizationService.isFeatureAllowed(featureId, profile);
  }

  /// Get recommended throttle percentage (0-100).
  int getRecommendedThrottlePercent() {
    return _optimizationService.getRecommendedThrottlePercent();
  }

  /// Stream of resource state changes.
  Stream<ResourceState> stateStream() {
    return _optimizationService.stateStream();
  }

  /// Get current optimization profile.
  BatteryOptimizationProfile get currentProfile => _optimizationService.currentProfile;
}

final resourceOptimizationOrchestratorProvider =
    Provider<ResourceOptimizationOrchestrator>((ref) {
  return ResourceOptimizationOrchestrator(
    optimizationService: ref.watch(resourceOptimizationServiceProvider),
    resourceRepository: ref.watch(systemResourceRepositoryProvider),
  );
});
