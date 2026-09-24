/// tool_permission_adapter.dart
/// AURA Assistant – Step 20: Tool Registry & Permissions
library;

import 'package:texo/features/tool_registry/application/contracts/tool_permission_adapter.dart';

export 'package:texo/features/tool_registry/application/contracts/tool_permission_adapter.dart';

import 'package:texo/features/tool_registry/domain/models/models.dart';
import 'package:texo/features/central_permissions/domain/central_permission_service.dart';
import 'package:texo/features/device_integration/domain/models/permission_status.dart';

class DefaultToolPermissionAdapter implements ToolPermissionAdapter {
  bool _isAvailable = false;

  /// Pre-configured permission statuses for testing.
  final Map<String, String> _preconfiguredStatuses;

  DefaultToolPermissionAdapter({
    bool isAvailable = false,
    Map<String, String>? preconfiguredStatuses,
  })  : _isAvailable = isAvailable,
        _preconfiguredStatuses = preconfiguredStatuses ?? {};

  @override
  Future<ToolPermissionResult> checkPermissions({
    required String toolId,
    required List<String> requiredPermissions,
  }) async {
    // FAIL CLOSED: if service unavailable, all undetermined.
    if (!_isAvailable) {
      return ToolPermissionResult.failClosed(
        permissions: requiredPermissions,
        reason: 'Permission service unavailable – fail-closed for tool: $toolId',
      );
    }

    final granted = <String>[];
    final denied = <String>[];
    final notDetermined = <String>[];

    for (final perm in requiredPermissions) {
      final status = _preconfiguredStatuses[perm] ?? 'unknown';
      switch (status) {
        case 'granted':
          granted.add(perm);
          break;
        case 'denied':
          denied.add(perm);
          break;
        default:
          // 'notDetermined', 'unknown', or anything else → fail closed.
          notDetermined.add(perm);
          break;
      }
    }

    return ToolPermissionResult(
      allGranted: denied.isEmpty && notDetermined.isEmpty,
      granted: granted,
      denied: denied,
      notDetermined: notDetermined,
    );
  }

  @override
  Future<ToolPermissionResult> requestPermissions({
    required String toolId,
    required List<String> permissions,
  }) async {
    // Default adapter does not actually request permissions.
    // Returns current status.
    return checkPermissions(toolId: toolId, requiredPermissions: permissions);
  }

  @override
  bool get isAvailable => _isAvailable;

  @override
  Future<String> checkSinglePermission(String permissionId) async {
    if (!_isAvailable) return 'unknown';
    return _preconfiguredStatuses[permissionId] ?? 'unknown';
  }

  /// Configure availability (for testing or live binding).
  void setAvailable(bool available) => _isAvailable = available;

  /// Add/update a preconfigured permission status.
  void setPermissionStatus(String permissionId, String status) {
    _preconfiguredStatuses[permissionId] = status;
  }
}

/// Production adapter that bridges Step 16's CentralPermissionService.
///
/// Translates string permission identifiers to Step 16's
/// DevicePermission enum values and checks status.
class Step16PermissionAdapter implements ToolPermissionAdapter {
  final CentralPermissionService _permissionService;
  bool _isAvailable;

  Step16PermissionAdapter({
    required CentralPermissionService permissionService,
    bool isAvailable = true,
  })  : _permissionService = permissionService,
        _isAvailable = isAvailable;

  @override
  Future<ToolPermissionResult> checkPermissions({
    required String toolId,
    required List<String> requiredPermissions,
  }) async {
    if (!_isAvailable) {
      return ToolPermissionResult.failClosed(
        permissions: requiredPermissions,
        reason:
            'Central permission service unavailable – '
            'fail-closed for tool: $toolId',
      );
    }

    try {
      final granted = <String>[];
      final denied = <String>[];
      final notDetermined = <String>[];

      for (final permissionId in requiredPermissions) {
        final permission = _resolvePermission(permissionId);
        if (permission == null) {
          notDetermined.add(permissionId);
          continue;
        }

        final result = await _permissionService.checkStatus(permission);

        if (!result.isSuccess) {
          notDetermined.add(permissionId);
          continue;
        }

        final status = result.valueOrNull?.status;
        switch (status) {
          case PermissionStatus.granted:
            granted.add(permissionId);
            break;
          case PermissionStatus.denied:
          case PermissionStatus.permanentlyDenied:
            denied.add(permissionId);
            break;
          case PermissionStatus.notRequested:
          case PermissionStatus.unknown:
          case null:
            notDetermined.add(permissionId);
            break;
        }
      }

      return ToolPermissionResult(
        allGranted: denied.isEmpty && notDetermined.isEmpty,
        granted: granted,
        denied: denied,
        notDetermined: notDetermined,
      );
    } catch (e) {
      return ToolPermissionResult.failClosed(
        permissions: requiredPermissions,
        reason:
            'Central permission check threw: $e – '
            'fail-closed for tool: $toolId',
      );
    }
  }

  @override
  Future<ToolPermissionResult> requestPermissions({
    required String toolId,
    required List<String> permissions,
  }) async {
    if (!_isAvailable) {
      return ToolPermissionResult.failClosed(
        permissions: permissions,
        reason: 'Central permission service unavailable – fail-closed',
      );
    }

    try {
      for (final permissionId in permissions) {
        final permission = _resolvePermission(permissionId);
        if (permission == null) {
          return ToolPermissionResult.failClosed(
            permissions: permissions,
            reason:
                'Unknown permission "$permissionId" – '
                'fail-closed for tool: $toolId',
          );
        }

        final result =
            await _permissionService.requestPermission(permission);

        if (!result.isSuccess ||
            result.valueOrNull?.status != PermissionStatus.granted) {
          return ToolPermissionResult.failClosed(
            permissions: permissions,
            reason:
                'Permission "$permissionId" was not granted – '
                'fail-closed for tool: $toolId',
          );
        }
      }

      return checkPermissions(
        toolId: toolId,
        requiredPermissions: permissions,
      );
    } catch (e) {
      return ToolPermissionResult.failClosed(
        permissions: permissions,
        reason:
            'Central permission request threw: $e – '
            'fail-closed for tool: $toolId',
      );
    }
  }

  @override
  bool get isAvailable => _isAvailable;

  @override
  Future<String> checkSinglePermission(String permissionId) async {
    if (!_isAvailable) return 'unknown';

    try {
      final permission = _resolvePermission(permissionId);
      if (permission == null) return 'unknown';

      final result = await _permissionService.checkStatus(permission);
      if (!result.isSuccess) return 'unknown';

      switch (result.valueOrNull?.status) {
        case PermissionStatus.granted:
          return 'granted';
        case PermissionStatus.denied:
          return 'denied';
        case PermissionStatus.permanentlyDenied:
          return 'permanentlyDenied';
        case PermissionStatus.notRequested:
          return 'notDetermined';
        case PermissionStatus.unknown:
        case null:
          return 'unknown';
      }
    } catch (_) {
      return 'unknown';
    }
  }

  DevicePermission? _resolvePermission(String permissionId) {
    final normalized = permissionId.trim().toLowerCase();

    for (final permission in DevicePermission.values) {
      if (permission.name.toLowerCase() == normalized) {
        return permission;
      }
    }

    return null;
  }

  void setAvailable(bool available) => _isAvailable = available;
}
