/// stub_system_resource_repository.dart
/// AURA Assistant – Step 27: Resource Optimization
///
/// FAIL-CLOSED stub: battery=0, thermal=critical, cpu/mem=max.
library;

import '../domain/models/resource_state.dart';
import '../domain/repositories/system_resource_repository.dart';

class StubSystemResourceRepository implements SystemResourceRepository {
  @override
  bool get isAvailable => false;

  @override
  Future<double> getBatteryLevel() async => 0.0;

  @override
  Future<bool> isCharging() async => false;

  @override
  Future<ThermalStatus> getThermalStatus() async => ThermalStatus.unknown;

  @override
  Future<double> getCpuUsage() async => 1.0;

  @override
  Future<double> getMemoryUsage() async => 1.0;

  @override
  Future<bool> isLowPowerMode() async => true;

  @override
  Future<ResourceState> getFullState() async => ResourceState.critical;

  @override
  Stream<ResourceState> resourceStateStream() => const Stream.empty();
}
