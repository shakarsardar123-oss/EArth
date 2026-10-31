/// device_connection_orchestrator.dart
/// AURA Assistant – Step 27: Cross-Device Connectivity & Control
///
/// Application-layer orchestrator coordinating DeviceConnectionService
/// and DeviceTransportRepository. FAIL-CLOSED: unknown→DENY, error→DENY.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/device_command.dart';
import '../domain/models/device_connection_state.dart';
import '../domain/repositories/device_transport_repository.dart';
import '../domain/services/device_connection_service.dart';
import 'providers.dart';

/// Orchestrates cross-device connectivity.
/// Delegates security decisions to DeviceConnectionService,
/// transport operations to DeviceTransportRepository.
/// FAIL-CLOSED: transport failure → deny, unknown state → deny.
class DeviceConnectionOrchestrator {
  final DeviceConnectionService _connectionService;
  final DeviceTransportRepository _transportRepository;

  DeviceConnectionOrchestrator({
    required DeviceConnectionService connectionService,
    required DeviceTransportRepository transportRepository,
  })  : _connectionService = connectionService,
        _transportRepository = transportRepository;

  /// Discover nearby devices via transport repository scan.
  /// FAIL-CLOSED: transport unavailable → empty list.
  Future<List<DeviceConnectionState>> discoverDevices() async {
    final available = await _transportRepository.isTransportAvailable();
    if (!available) return [];
    return _transportRepository.scanDevices();
  }

  /// Connect to a device: authorize first, then establish transport.
  /// FAIL-CLOSED: authorization denied → return disconnected state.
  Future<DeviceConnectionState> connect(String deviceId) async {
    // Authorize device via service
    final verdict = await _connectionService.authorizeDevice(deviceId);
    if (verdict.isDenied) {
      return DeviceConnectionState(
        deviceId: deviceId,
        status: DeviceConnectionStatus.denied,
        transportType: _transportRepository.transportType,
      );
    }
    // Establish transport connection
    final result = await _transportRepository.establishConnection(deviceId);
    if (!result.success) {
      return DeviceConnectionState(
        deviceId: deviceId,
        status: DeviceConnectionStatus.error,
        transportType: _transportRepository.transportType,
      );
    }
    final connId = result.data?['connectionId'] as String? ?? deviceId;
    return _connectionService.connect(deviceId, _transportRepository.transportType);
  }

  /// Disconnect a device by connection ID.
  /// FAIL-CLOSED: terminate failure → still report disconnected.
  Future<DeviceConnectionState> disconnect(String connectionId) async {
    final result = await _transportRepository.terminateConnection(connectionId);
    if (!result.success) {
      // Still attempt service disconnect for state cleanup
      return _connectionService.disconnect(connectionId);
    }
    return _connectionService.disconnect(connectionId);
  }

  /// Get current connection state from service.
  DeviceConnectionState getConnectionState(String connectionId) {
    return _connectionService.getConnectionState(connectionId);
  }

  /// Send a command to a connected device.
  /// FAIL-CLOSED: security check fails → deny, transport fails → deny.
  Future<DeviceCommandResult> sendCommand(DeviceCommand command) async {
    // Security check via service
    final serviceResult = await _connectionService.sendCommand(command);
    if (serviceResult.isDenied) return serviceResult;
    // Transport-level send
    final transportResult = await _transportRepository.sendRaw(
      command.connectionId,
      command.payload,
    );
    if (!transportResult.success) {
      return DeviceCommandResult.denied;
    }
    return DeviceCommandResult.success;
  }
}

/// Provider for DeviceConnectionOrchestrator.
final deviceConnectionOrchestratorProvider = Provider<DeviceConnectionOrchestrator>((ref) {
  return DeviceConnectionOrchestrator(
    connectionService: ref.watch(deviceConnectionServiceProvider),
    transportRepository: ref.watch(deviceTransportRepositoryProvider),
  );
});
