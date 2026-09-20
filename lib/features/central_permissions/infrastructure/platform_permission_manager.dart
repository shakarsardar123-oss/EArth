// ───────────────────────────────────────────────────────────────────
// Step 16 – Central Permissions · Infrastructure · Platform impl
// ───────────────────────────────────────────────────────────────────
// MethodChannel-based implementation of [CentralPermissionService].
//
// Method channel: com.aura.assistant/central_permissions
//
// Supported method calls:
//   checkStatus     → {permission: String}  → {status: String}
//   requestPermission → {permission: String}  → {status: String, isGranted: bool}
//   shouldShowRationale → {permission: String} → {show: bool}
//   openSettings    → {permission: String}  → {success: bool}
//   checkAll        → {permissions: [String]} → {statuses: {String: String}}
// ───────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/services.dart';

import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'package:aura_assistant/features/central_permissions/domain/central_permission_service.dart';
import 'package:aura_assistant/features/central_permissions/domain/models/central_permission_failure.dart';

/// Platform-channel implementation of [CentralPermissionService].
///
/// All actual permission state comes from the native side — this class
/// NEVER fakes or bypasses a permission.
class PlatformPermissionManager extends CentralPermissionService {
  static const MethodChannel _channel =
      MethodChannel('com.aura.assistant/central_permissions');

  // ── Feature → Permission mapping ─────────────────────────────────

  static const Map<String, List<DevicePermission>> _featurePermissions = {
    'voice_screen': [DevicePermission.microphone],
    'vision': [DevicePermission.camera],
    'screen_capture': [DevicePermission.screenCapture],
    'floating_overlay': [DevicePermission.overlay],
    'assistant_integration': [DevicePermission.assistant],
    'device_integration': [
      DevicePermission.accessibility,
      DevicePermission.overlay,
      DevicePermission.screenCapture,
    ],
    // RESTORED: storage needed by VisionTool (gallery), MediaTool, file_storage_adapter
    'file_storage': [DevicePermission.storage],
    'notifications': [DevicePermission.notification],
    'foreground_service': [DevicePermission.batteryOptimization],
    // RESTORED: location needed by NavigationTool, MemoryType.location, system_settings_tool
    'location_services': [DevicePermission.location],
    'exact_alarm': [DevicePermission.exactAlarm],
  };

  @override
  List<DevicePermission> permissionsForFeature(String featureName) =>
      _featurePermissions[featureName] ??
      [
        DevicePermission.values.firstWhere(
          (p) => p.name == featureName,
          orElse: () => DevicePermission.accessibility,
        )
      ];

  @override
  List<String> featuresRequiringPermission(DevicePermission permission) =>
      _featurePermissions.entries
          .where((e) => e.value.contains(permission))
          .map((e) => e.key)
          .toList();

  // ── Single-permission operations ────────────────────────────────

  @override
  Future<CentralPermissionResult<PermissionResult>> checkStatus(
    DevicePermission permission,
  ) async {
    try {
      final result = await _channel.invokeMethod<Map>(
        'checkStatus',
        {'permission': permission.name},
      );
      if (result == null) {
        return Result.failure(
          CentralPermissionFailure.check(
            permission: permission,
            action: 'retry',
          ),
        );
      }
      final status = _parseStatus(result['status'] as String?);
      return Result.success(
        PermissionResult.single(permission: permission, status: status),
      );
    } on PlatformException catch (e) {
      return Result.failure(
        CentralPermissionFailure.check(
          permission: permission,
          action: 'retry',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<CentralPermissionResult<PermissionResult>> requestPermission(
    DevicePermission permission,
  ) async {
    try {
      final result = await _channel.invokeMethod<Map>(
        'requestPermission',
        {'permission': permission.name},
      );
      if (result == null) {
        return Result.failure(
          CentralPermissionFailure.request(
            permission: permission,
            status: PermissionStatus.denied,
            action: 'retry',
          ),
        );
      }
      final status = _parseStatus(result['status'] as String?);
      return Result.success(
        PermissionResult.single(permission: permission, status: status),
      );
    } on PlatformException catch (e) {
      return Result.failure(
        CentralPermissionFailure.request(
          permission: permission,
          status: PermissionStatus.denied,
          action: 'retry',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<bool> shouldShowRationale(DevicePermission permission) async {
    try {
      final result = await _channel.invokeMethod<Map>(
        'shouldShowRationale',
        {'permission': permission.name},
      );
      return result?['show'] as bool? ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<CentralPermissionResult<void>> openSettings(
    DevicePermission permission,
  ) async {
    try {
      final result = await _channel.invokeMethod<Map>(
        'openSettings',
        {'permission': permission.name},
      );
      if (result?['success'] as bool? ?? false) {
        return Result.success(null);
      }
      return Result.failure(
        CentralPermissionFailure.settings(
          permission: permission,
          action: 'open_settings_manually',
        ),
      );
    } on PlatformException catch (e) {
      return Result.failure(
        CentralPermissionFailure.settings(
          permission: permission,
          action: 'open_settings_manually',
          cause: e,
        ),
      );
    }
  }

  // ── Batch operations ────────────────────────────────────────────

  @override
  Future<Map<DevicePermission, PermissionStatus>> checkAll(
    Iterable<DevicePermission> permissions,
  ) async {
    final names = permissions.map((p) => p.name).toList();
    try {
      final result = await _channel.invokeMethod<Map>(
        'checkAll',
        {'permissions': names},
      );
      final statusMap = result?['statuses'] as Map? ?? {};
      return {
        for (final e in statusMap.entries)
          _parsePermission(e.key as String):
              _parseStatus(e.value as String?),
      };
    } on PlatformException {
      // On platform error, return unknown for all.
      return {
        for (final p in permissions) p: PermissionStatus.unknown,
      };
    }
  }

  @override
  Future<Map<DevicePermission, CentralPermissionResult<PermissionResult>>>
      requestAll(
    Iterable<DevicePermission> permissions,
  ) async {
    final results =
        <DevicePermission, CentralPermissionResult<PermissionResult>>{};
    for (final p in permissions) {
      final r = await requestPermission(p);
      if (r.isSuccess) {
        results[p] = Result.success(r.valueOrNull!);
      } else {
        results[p] = Result.failure(
          CentralPermissionFailure.request(
            permission: p,
            status: PermissionStatus.denied,
            cause: r.failureOrNull,
          ),
        );
      }
    }
    return results;
  }

  // ── Parsing helpers ─────────────────────────────────────────────

  static PermissionStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'granted':
        return PermissionStatus.granted;
      case 'denied':
        return PermissionStatus.denied;
      case 'permanentlyDenied':
        return PermissionStatus.permanentlyDenied;
      default:
        return PermissionStatus.unknown;
    }
  }

  static DevicePermission _parsePermission(String raw) {
    return DevicePermission.values.firstWhere(
      (p) => p.name == raw,
      orElse: () => DevicePermission.accessibility,
    );
  }
}
