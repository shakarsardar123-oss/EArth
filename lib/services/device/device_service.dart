/// Abstraction for device-level information and capabilities.
///
/// Phase 2+ will implement platform channels. Phase 1 provides
/// the contract only.
abstract class DeviceService {
  /// The device model name (e.g. 'Pixel 7').
  Future<String> getDeviceModel();

  /// The OS version string.
  Future<String> getOsVersion();

  /// A stable device identifier for analytics.
  Future<String> getDeviceId();

  /// Whether the device currently has internet connectivity.
  Future<bool> isNetworkAvailable();

  /// Current battery level (0-100), or `null` if unavailable.
  Future<int?> getBatteryLevel();
}
