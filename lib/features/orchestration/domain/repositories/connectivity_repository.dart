/// Step 23 — Connectivity Repository Interface
///
/// Contract for checking network/online status.
/// Used by the orchestrator for offline degradation decisions.

abstract class ConnectivityRepository {
  /// Whether the device currently has internet connectivity.
  Future<bool> isOnline();

  /// Stream of connectivity changes (for reactive updates).
  Stream<bool> get onConnectivityChanged;
}
