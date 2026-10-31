/// system_resource_repository.dart
/// AURA Assistant – Step 27: Battery & Thermal Optimization
///
/// Domain repository contract for system resource monitoring.
/// FAIL-CLOSED: any error → critical, unavailable → critical.
library;

import '../models/resource_state.dart';

/// Result of a system resource operation.
enum SystemResourceResult {
  success,
  unavailable,
  error,
  unknown,
  ;

  bool get isSuccess => this == success;
  bool get isDenied => this == unavailable || this == error || this == unknown;
}

/// Abstract repository for system resource monitoring.
/// Infrastructure adapters must implement this interface EXACTLY.
abstract class SystemResourceRepository {
  /// Get the current battery level (0.0-1.0).
  /// FAIL-CLOSED: unknown → 0.0.
  Future<double> getBatteryLevel();

  /// Check if the device is charging.
  /// FAIL-CLOSED: unknown → false.
  Future<bool> isCharging();

  /// Get the current thermal status.
  /// FAIL-CLOSED: unknown → critical.
  Future<ThermalStatus> getThermalStatus();

  /// Get the current CPU usage (0.0-1.0).
  /// FAIL-CLOSED: unknown → 1.0.
  Future<double> getCpuUsage();

  /// Get the current memory usage (0.0-1.0).
  /// FAIL-CLOSED: unknown → 1.0.
  Future<double> getMemoryUsage();

  /// Check if low-power mode is active.
  /// FAIL-CLOSED: unknown → true.
  Future<bool> isLowPowerMode();

  /// Get the complete resource state.
  /// FAIL-CLOSED: any error → critical state.
  Future<ResourceState> getFullState();

  /// Stream of resource state updates.
  /// FAIL-CLOSED: on error, emits critical state then closes.
  Stream<ResourceState> resourceStateStream();

  /// Check if system resource monitoring is available.
  bool get isAvailable;
}
