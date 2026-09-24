/// tool_permission_adapter.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Adapter that bridges Step 16's CentralPermissionService into the
/// Tool Registry's execution pipeline.
///
/// Translates tool's requiredPermissions (string identifiers) into
/// Step 16 permission checks.
library;

import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/models.dart';

/// Permission check result for a tool execution.
class ToolPermissionResult {
  final bool allGranted;
  final List<String> granted;
  final List<String> denied;
  final List<String> notDetermined;

  const ToolPermissionResult({
    required this.allGranted,
    this.granted = const [],
    this.denied = const [],
    this.notDetermined = const [],
  });

  /// All permissions granted.
  factory ToolPermissionResult.allGranted(List<String> permissions) =>
      ToolPermissionResult(
        allGranted: true,
        granted: permissions,
      );

  /// Some permissions denied.
  factory ToolPermissionResult.someDenied({
    required List<String> granted,
    required List<String> denied,
    List<String>? notDetermined,
  }) =>
      ToolPermissionResult(
        allGranted: false,
        granted: granted,
        denied: denied,
        notDetermined: notDetermined ?? const [],
      );

  /// Fail-closed: permissions could not be determined.
  factory ToolPermissionResult.failClosed({
    required List<String> permissions,
    String? reason,
  }) =>
      ToolPermissionResult(
        allGranted: false,
        notDetermined: permissions,
      );

  /// FAIL CLOSED: any non-granted permission means execution is denied.
  bool get permitsExecution => allGranted;
}

/// Abstract interface for the permission adapter.
///
/// Bridges Step 16's CentralPermissionService so the tool
/// registry does not depend on it directly.
abstract class ToolPermissionAdapter {
  /// Check all required permissions for a tool.
  ///
  /// [toolId] – the tool being executed.
  /// [requiredPermissions] – string identifiers from ToolDefinition.
  ///
  /// Returns [ToolPermissionResult] indicating which permissions
  /// are granted/denied/not determined.
  /// FAIL CLOSED: if the permission service is unavailable,
  /// returns fail-closed (all permissions undetermined).
  Future<ToolPermissionResult> checkPermissions({
    required String toolId,
    required List<String> requiredPermissions,
  });

  /// Request permissions that are not yet granted.
  ///
  /// Returns the result of the permission request.
  Future<ToolPermissionResult> requestPermissions({
    required String toolId,
    required List<String> permissions,
  });

  /// Whether the permission service is currently available.
  bool get isAvailable;

  /// Check a single permission status.
  /// Returns 'granted', 'denied', 'notDetermined', or 'unknown'.
  Future<String> checkSinglePermission(String permissionId);
}

/// Default implementation that fails closed when no real
/// permission service is available.
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
  /// The Step 16 permission service instance.
  ///
  /// Type is dynamic to avoid direct import. Expected to implement:
  ///   checkStatus(DevicePermission) -> PermissionStatus
  ///   requestPermission(DevicePermission) -> PermissionStatus
  ///   checkAll(List<DevicePermission>) -> Map<DevicePermission, PermissionStatus>
  final dynamic _permissionService;

  bool _isAvailable;

  /// Map of string permission IDs to Step 16 DevicePermission enum names.
  final Map<String, String> _permissionMapping;

  Step16PermissionAdapter({
    required dynamic permissionService,
    bool isAvailable = true,
    Map<String, String>? permissionMapping,
  })  : _permissionService = permissionService,
        _isAvailable = isAvailable,
        _permissionMapping = permissionMapping ?? _defaultMapping;

  /// Default mapping from string IDs to Step 16 DevicePermission names.
  static const Map<String, String> _defaultMapping = {
    'microphone': 'microphone',
    'camera': 'camera',
    'location': 'location',
    'storage': 'storage',
    'contacts': 'contacts',
    'phone': 'phone',
    'notifications': 'notifications',
    'bluetooth': 'bluetooth',
    'calendar': 'calendar',
    'sensors': 'sensors',
  };

  @override
  Future<ToolPermissionResult> checkPermissions({
    required String toolId,
    required List<String> requiredPermissions,
  }) async {
    // FAIL CLOSED: if service unavailable.
    if (!_isAvailable || _permissionService == null) {
      return ToolPermissionResult.failClosed(
        permissions: requiredPermissions,
        reason: 'Step 16 permission service unavailable – '
            'fail-closed for tool: $toolId',
      );
    }

    try {
      final granted = <String>[];
      final denied = <String>[];
      final notDetermined = <String>[];

      for (final permId in requiredPermissions) {
        final step16Name = _permissionMapping[permId] ?? permId;
        final status = await _checkSingleViaStep16(step16Name);

        switch (status) {
          case 'granted':
            granted.add(permId);
            break;
          case 'denied':
            denied.add(permId);
            break;
          default:
            // 'notDetermined', 'unknown' → fail closed.
            notDetermined.add(permId);
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
      // FAIL CLOSED: any exception → deny.
      return ToolPermissionResult.failClosed(
        permissions: requiredPermissions,
        reason: 'Step 16 permission check threw: $e – '
            'fail-closed for tool: $toolId',
      );
    }
  }

  @override
  Future<ToolPermissionResult> requestPermissions({
    required String toolId,
    required List<String> permissions,
  }) async {
    // FAIL CLOSED: if unavailable.
    if (!_isAvailable || _permissionService == null) {
      return ToolPermissionResult.failClosed(
        permissions: permissions,
        reason: 'Step 16 unavailable for request – fail-closed',
      );
    }

    try {
      for (final permId in permissions) {
        final step16Name = _permissionMapping[permId] ?? permId;
        // Step 16 expected: requestPermission(DevicePermission)
        await _permissionService.requestPermission(
          _resolveDevicePermission(step16Name),
        );
      }

      // Re-check after requesting.
      return checkPermissions(toolId: toolId, requiredPermissions: permissions);
    } catch (e) {
      return ToolPermissionResult.failClosed(
        permissions: permissions,
        reason: 'Step 16 request threw: $e – fail-closed',
      );
    }
  }

  @override
  bool get isAvailable => _isAvailable;

  @override
  Future<String> checkSinglePermission(String permissionId) async {
    if (!_isAvailable || _permissionService == null) return 'unknown';
    try {
      final step16Name = _permissionMapping[permissionId] ?? permissionId;
      return _checkSingleViaStep16(step16Name);
    } catch (_) {
      return 'unknown';
    }
  }

  /// Internal: check single permission via Step 16.
  Future<String> _checkSingleViaStep16(String step16Name) async {
    try {
      final result =
          await _permissionService.checkStatus(
            _resolveDevicePermission(step16Name),
          );
      // Translate Step 16 PermissionStatus to string.
      final statusStr = result.toString().toLowerCase();
      if (statusStr.contains('granted')) return 'granted';
      if (statusStr.contains('denied')) return 'denied';
      return 'notDetermined';
    } catch (_) {
      return 'unknown';
    }
  }

  /// Resolve a string name to a DevicePermission-like object.
  ///
  /// Uses dynamic invocation to avoid direct type coupling.
  dynamic _resolveDevicePermission(String name) {
    try {
      // Try to find the enum value by name.
      final values = _permissionService.devicePermissionValues;
      if (values is List) {
        for (final v in values) {
          if (v.toString().toLowerCase().contains(name.toLowerCase())) {
            return v;
          }
        }
      }
    } catch (_) {
      // Fall through to string.
    }
    return name; // fallback: pass as string
  }

  /// Update availability.
  void setAvailable(bool available) => _isAvailable = available;
}
