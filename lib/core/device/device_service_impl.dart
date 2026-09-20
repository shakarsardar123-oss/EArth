import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Real device service implementation using device_info_plus and connectivity_plus.
class DeviceServiceImpl {
  DeviceServiceImpl();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Connectivity _connectivity = Connectivity();

  /// Returns a map of device information.
  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      // For Android
      final androidInfo = await _deviceInfo.androidInfo;
      return {
        'brand': androidInfo.brand,
        'model': androidInfo.model,
        'manufacturer': androidInfo.manufacturer,
        'androidVersion': androidInfo.version.release,
        'sdkInt': androidInfo.version.sdkInt,
        'device': androidInfo.device,
        'isPhysicalDevice': androidInfo.isPhysicalDevice,
        'board': androidInfo.board,
        'hardware': androidInfo.hardware,
      };
    } catch (e) {
      return {'error': 'Failed to get device info: $e'};
    }
  }

  /// Checks if the device is currently connected to the internet.
  Future<bool> isConnected() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  /// Stream of connectivity changes.
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map((results) {
      return results.any((r) => r != ConnectivityResult.none);
    });
  }

  /// Returns the current connectivity type as a string.
  Future<String> getConnectivityType() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.contains(ConnectivityResult.wifi)) return 'wifi';
      if (results.contains(ConnectivityResult.mobile)) return 'mobile';
      if (results.contains(ConnectivityResult.ethernet)) return 'ethernet';
      if (results.contains(ConnectivityResult.none)) return 'none';
      return 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }
}
