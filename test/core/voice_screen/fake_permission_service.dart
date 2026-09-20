/// Hand-written fake [PermissionService] for voice-screen engine tests.
library;

import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:aura_assistant/core/permissions/permission_service.dart';
import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/core/errors/failures.dart';

/// Configuration for [FakePermissionService].
class FakePermissionConfig {
  /// Whether [requestPermission] returns a granted result.
  final bool grantPermission;

  /// If non-null and [grantPermission] is false, this failure is returned.
  final PermissionFailure? failure;

  /// If true, [requestPermission] throws an unexpected exception.
  final bool shouldThrow;

  /// Delay before returning from [requestPermission].
  final Duration delay;

  const FakePermissionConfig({
    this.grantPermission = true,
    this.failure,
    this.shouldThrow = false,
    this.delay = Duration.zero,
  });
}

/// A fake [PermissionService] that extends the concrete class
/// and overrides [requestPermission] for test control.
///
/// - Call [configure] before each test to set up expected outcomes.
/// - Tracks call counts and last arguments for assertions.
class FakePermissionService extends PermissionService {
  FakePermissionConfig _config = const FakePermissionConfig();

  /// Call counts for verification.
  int requestPermissionCallCount = 0;
  int isPermissionGrantedCallCount = 0;
  int isPermissionPermanentlyDeniedCallCount = 0;
  int openAppSettingsCallCount = 0;
  int requestAllRequiredPermissionsCallCount = 0;

  /// Last arguments for verification.
  ph.Permission? lastPermission;

  FakePermissionService() : super();

  /// Configure the fake's behaviour.
  void configure(FakePermissionConfig config) {
    _config = config;
  }

  @override
  Future<Result<bool, PermissionFailure>> requestPermission(
    ph.Permission permission,
  ) async {
    requestPermissionCallCount++;
    lastPermission = permission;

    if (_config.delay > Duration.zero) {
      await Future.delayed(_config.delay);
    }

    if (_config.shouldThrow) {
      throw Exception('Unexpected error in fake permission service');
    }

    if (_config.grantPermission) {
      return Result.success(true);
    }

    if (_config.failure != null) {
      return Result.failure(_config.failure!);
    }

    // Default denial when not granted and no specific failure.
    return Result.failure(PermissionFailure(
      message: 'Permission ${permission.toString()} denied',
      code: 'PERMISSION_DENIED',
      permission: permission.toString(),
    ));
  }

  @override
  Future<bool> isPermissionGranted(ph.Permission permission) async {
    isPermissionGrantedCallCount++;
    lastPermission = permission;
    return _config.grantPermission;
  }

  @override
  Future<bool> isPermissionPermanentlyDenied(ph.Permission permission) async {
    isPermissionPermanentlyDeniedCallCount++;
    return false;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCallCount++;
    return true;
  }

  @override
  Future<Map<ph.Permission, bool>> requestAllRequiredPermissions() async {
    requestAllRequiredPermissionsCallCount++;
    return {ph.Permission.microphone: _config.grantPermission};
  }
}
