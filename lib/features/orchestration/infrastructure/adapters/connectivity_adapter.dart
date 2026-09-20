/// Step 23 — Connectivity Adapter
///
/// Adapter implementing [ConnectivityRepository] by delegating to the
/// canonical [DeviceServiceImpl] (backed by `connectivity_plus`).
///
/// ConnectivityRepository: isOnline()→Future<bool>,
///   onConnectivityChanged→Stream<bool>.
///
/// FAIL-CLOSED: on error / unavailable, [DeviceServiceImpl.isConnected]
/// already returns `false` (its catch block), so the orchestrator treats
/// the request as offline and degrades safely. This adapter does NOT invent
/// a second connectivity source — it reuses the one real service the app
/// already wires through `deviceServiceProvider`.

import '../../../../core/device/device_service_impl.dart';
import '../../domain/orchestration_domain.dart';

class ConnectivityAdapter implements ConnectivityRepository {
  /// The canonical device service (connectivity_plus backed).
  final DeviceServiceImpl _deviceService;

  /// Wire the adapter to the real [DeviceServiceImpl].
  ///
  /// The service is injected (never constructed here) so the same
  /// singleton instance from `deviceServiceProvider` is reused and no
  /// competing connectivity source is created.
  ConnectivityAdapter(this._deviceService);

  @override
  Future<bool> isOnline() async {
    try {
      // Delegate to the real service. DeviceServiceImpl.isConnected()
      // already FAIL-CLOSEs to false on any error.
      return await _deviceService.isConnected();
    } catch (_) {
      // Defensive FAIL-CLOSED: unknown → offline.
      return false;
    }
  }

  @override
  Stream<bool> get onConnectivityChanged => _deviceService.onConnectivityChanged;
}
