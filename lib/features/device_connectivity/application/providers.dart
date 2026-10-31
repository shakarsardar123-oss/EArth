/// providers.dart
/// AURA Assistant – Step 27: Device Connectivity — Riverpod providers
/// FAIL-CLOSED: every provider defaults to safe/denied on error.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/device_connection_state.dart';
import '../domain/repositories/device_transport_repository.dart';
import '../domain/services/device_connection_service.dart';

/// Service provider — will be overridden by infrastructure.
final deviceConnectionServiceProvider = Provider<DeviceConnectionService>((ref) {
  throw UnimplementedError('deviceConnectionServiceProvider must be overridden');
});

/// Repository provider — will be overridden by infrastructure.
final deviceTransportRepositoryProvider = Provider<DeviceTransportRepository>((ref) {
  throw UnimplementedError('deviceTransportRepositoryProvider must be overridden');
});

/// Currently connected devices list.
final connectedDevicesProvider = StateProvider<List<DeviceConnectionState>>((ref) => []);

/// Whether transport is available.
final transportAvailableProvider = StateProvider<bool>((ref) => false);
