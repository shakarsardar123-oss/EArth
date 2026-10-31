/// device_transport_repository.dart
/// AURA Assistant – Step 27: Cross-Device Connectivity & Control
///
/// Abstract repository interface for low-level device transport operations.
/// Infrastructure adapters must implement this interface EXACTLY.
/// FAIL-CLOSED: unknown → error, unavailable → null.
library;

import '../models/device_connection_state.dart';
import '../../../../core/errors/result.dart';

/// Result of a raw transport operation.
class TransportResult {
  final bool success;
  final String? errorMessage;
  final Map<String, dynamic>? data;

  const TransportResult({
    this.success = false,
    this.errorMessage,
    this.data,
  });

  /// FAIL-CLOSED: error result.
  factory TransportResult.error(String message) =>
      TransportResult(success: false, errorMessage: message);

  /// Success result.
  factory TransportResult.ok(Map<String, dynamic> data) =>
      TransportResult(success: true, data: data);
}

/// Abstract repository for device transport operations.
/// Concrete adapters (Bluetooth, WiFi Direct, USB) implement this.
abstract class DeviceTransportRepository {
  /// Scan for available devices via this transport.
  /// FAIL-CLOSED: unavailable → empty list.
  Future<List<DeviceConnectionState>> scanDevices();

  /// Establish a connection via this transport.
  /// FAIL-CLOSED: failure → TransportResult.error.
  Future<TransportResult> establishConnection(String deviceId);

  /// Terminate a connection.
  /// FAIL-CLOSED: unknown → TransportResult.error.
  Future<TransportResult> terminateConnection(String connectionId);

  /// Send raw data/command over this transport.
  /// FAIL-CLOSED: failure → TransportResult.error.
  Future<TransportResult> sendRaw(String connectionId, Map<String, dynamic> payload);

  /// Check transport availability.
  Future<bool> isTransportAvailable();

  /// Get transport type identifier.
  String get transportType;
}
