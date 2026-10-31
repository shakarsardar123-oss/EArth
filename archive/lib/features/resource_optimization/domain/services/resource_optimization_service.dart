/// resource_optimization_service.dart
/// AURA Assistant – Step 27: Battery & Thermal Optimization
///
/// Domain service contract for resource optimization.
/// FAIL-CLOSED: unknown → maximum savings, error → maximum savings.
library;

import '../models/resource_state.dart';
import '../models/battery_optimization_profile.dart';

/// Verdict for resource optimization operations.
enum OptimizationVerdict {
  allowed,
  throttled,
  denied,
  deniedCritical,
  unknown,
  ;

  bool get isAllowed => this == allowed || this == throttled;
  bool get isDenied => this == denied || this == deniedCritical || this == unknown;
}

/// Abstract domain service for resource optimization.
/// Must be implemented by infrastructure adapters.
abstract class ResourceOptimizationService {
  /// Get the current resource state.
  /// FAIL-CLOSED: unknown → critical.
  Future<ResourceState> getCurrentState();

  /// Determine the optimal profile for the current resource state.
  /// FAIL-CLOSED: unknown → maximum savings.
  BatteryOptimizationProfile determineOptimalProfile(ResourceState state);

  /// Apply an optimization profile.
  /// FAIL-CLOSED: critical → denied (all features off).
  Future<OptimizationVerdict> applyProfile(BatteryOptimizationProfile profile);

  /// Check if a feature is allowed under the current profile.
  /// FAIL-CLOSED: unknown → denied.
  bool isFeatureAllowed(String featureId, BatteryOptimizationProfile profile);

  /// Get the recommended throttle percentage for the current state.
  /// FAIL-CLOSED: unknown → 90% throttle.
  int getRecommendedThrottlePercent();

  /// Stream of resource state changes.
  /// FAIL-CLOSED: on error, emits critical state then closes.
  Stream<ResourceState> stateStream();

  /// Check if resource monitoring is available.
  bool get isAvailable;

  /// Get the current optimization profile.
  BatteryOptimizationProfile get currentProfile;
}
