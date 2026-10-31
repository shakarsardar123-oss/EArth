/// providers.dart
/// AURA Assistant – Step 27: Resource Optimization — Riverpod providers
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/battery_optimization_profile.dart';
import '../domain/repositories/system_resource_repository.dart';
import '../domain/services/resource_optimization_service.dart';

final resourceOptimizationServiceProvider = Provider<ResourceOptimizationService>((ref) {
  throw UnimplementedError('resourceOptimizationServiceProvider must be overridden');
});

final systemResourceRepositoryProvider = Provider<SystemResourceRepository>((ref) {
  throw UnimplementedError('systemResourceRepositoryProvider must be overridden');
});

final currentBatteryProfileProvider = StateProvider<BatteryOptimizationProfile>(
  (ref) => BatteryOptimizationProfile.normal,
);

final throttlePercentProvider = StateProvider<int>((ref) => 0);
