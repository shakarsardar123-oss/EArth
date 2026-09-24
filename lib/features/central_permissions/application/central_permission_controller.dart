// ───────────────────────────────────────────────────────────────────
// Step 16 – Central Permissions · Application · Controller
// ───────────────────────────────────────────────────────────────────
// Orchestrates the full permission flow:
//   check → explain (if shouldShowRationale) → request → verify → settings
//
// NEVER silently grants, fakes, or bypasses permissions.
// ───────────────────────────────────────────────────────────────────

import 'package:texo/core/errors/result.dart';
import 'package:texo/features/device_integration/domain/models/permission_status.dart';
import 'package:texo/features/central_permissions/domain/central_permission_service.dart';
import 'package:texo/features/central_permissions/domain/models/central_permission_failure.dart';
import 'package:texo/features/central_permissions/domain/models/permission_explanation.dart';
import 'package:texo/features/central_permissions/application/central_permission_state.dart';

/// Callback signature for when the UI should display a rationale sheet.
typedef ShowRationaleCallback = Future<bool> Function(
  PermissionExplanation explanation,
);

/// Controller that owns the 5-step permission flow.
///
/// Usage:
///   1. Call [loadAllStatuses] to populate the state.
///   2. Call [requestPermission] for each needed permission.
///   3. If [ShowRationaleCallback] is provided, the controller will
///      ask the UI to display an explanation before the system dialog.
class CentralPermissionController {
  final CentralPermissionService _service;
  final ShowRationaleCallback? onShowRationale;

  CentralPermissionState _state = const CentralPermissionState();

  /// Stream of state changes (simplified – in production use a
  /// ChangeNotifier / Riverpod / Bloc).
  final List<void Function(CentralPermissionState)> _listeners = [];

  CentralPermissionController({
    required CentralPermissionService service,
    this.onShowRationale,
  }) : _service = service;

  // ── Read-only access ────────────────────────────────────────────

  CentralPermissionState get state => _state;

  void listen(void Function(CentralPermissionState) callback) {
    _listeners.add(callback);
  }

  void _emit(CentralPermissionState s) {
    _state = s;
    for (final cb in _listeners) {
      cb(s);
    }
  }

  // ── Actions ──────────────────────────────────────────────────────

  /// Load statuses for all [DevicePermission] values.
  Future<void> loadAllStatuses() async {
    _emit(_state.copyWith(isLoading: true, clearFailure: true));
    try {
      final statuses = await _service.checkAll(DevicePermission.values);
      _emit(_state.copyWith(statuses: statuses, isLoading: false));
    } on CentralPermissionFailure catch (f) {
      _emit(_state.copyWith(isLoading: false, failure: f));
    }
  }

  /// Load statuses for a specific feature's permissions.
  Future<void> loadFeatureStatuses(String featureName) async {
    final perms = _service.permissionsForFeature(featureName);
    _emit(_state.copyWith(isLoading: true, clearFailure: true));
    try {
      final statuses = await _service.checkAll(perms);
      _emit(
        _state.copyWith(
          statuses: {..._state.statuses, ...statuses},
          isLoading: false,
        ),
      );
    } on CentralPermissionFailure catch (f) {
      _emit(_state.copyWith(isLoading: false, failure: f));
    }
  }

  /// Full 5-step flow for a single permission.
  ///
  /// Returns `true` if the permission was ultimately granted.
  Future<bool> requestPermission(
    DevicePermission permission,
  ) async {
    _emit(_state.copyWith(
      activePermission: permission,
      clearFailure: true,
    ));

    try {
      // Step 1: check current status
      final checkResult = await _service.checkStatus(permission);
      if (checkResult.isFailure) {
        _emit(_state.copyWith(
          failure: CentralPermissionFailure.check(
            permission: permission,
            action: 'retry_check',
            cause: checkResult.failureOrNull,
          ),
        ));
        return false;
      }
      final currentStatus = checkResult.valueOrNull!.status;
      _emit(_state.copyWith(
        statuses: {..._state.statuses, permission: currentStatus},
      ));

      if (currentStatus == PermissionStatus.granted) return true;

      // Step 2: explain if rationale recommended
      final shouldExplain = await _service.shouldShowRationale(permission);
      if (shouldExplain && onShowRationale != null) {
        final explanation = PermissionExplanation.defaults[permission] ??
            PermissionExplanation(
              permission: permission,
              titleKey: 'perm_${permission.name}_title',
              bodyKey: 'perm_${permission.name}_body',
              featureName: 'unknown',
            );
        final userConfirmed = await onShowRationale!(explanation);
        if (!userConfirmed) {
          // User dismissed the rationale – do NOT request.
          return false;
        }
      }

      // Step 3: request the permission
      final requestResult = await _service.requestPermission(permission);
      if (requestResult.isFailure) {
        _emit(_state.copyWith(
          failure: CentralPermissionFailure.request(
            permission: permission,
            status: PermissionStatus.denied,
            action: 'retry_request',
            cause: requestResult.failureOrNull,
          ),
        ));
        return false;
      }
      final result = requestResult.valueOrNull!;

      // Step 4: verify – re-check status
      final verifyCheck = await _service.checkStatus(permission);
      final verifiedStatus = verifyCheck.isFailure
          ? result.status
          : verifyCheck.valueOrNull!.status;

      _emit(_state.copyWith(
        statuses: {..._state.statuses, permission: verifiedStatus},
      ));

      if (verifiedStatus == PermissionStatus.granted) return true;

      // Step 5: permanently denied → offer settings
      if (verifiedStatus == PermissionStatus.permanentlyDenied) {
        final openResult = await _service.openSettings(permission);
        if (openResult.isFailure) {
          _emit(_state.copyWith(
            failure: CentralPermissionFailure.settings(
              permission: permission,
              action: 'open_settings_manually',
              cause: openResult.failureOrNull,
            ),
          ));
        }
      }

      return false;
    } on CentralPermissionFailure catch (f) {
      _emit(_state.copyWith(failure: f));
      return false;
    }
  }

  /// Request all permissions needed for a feature.
  Future<Map<DevicePermission, bool>> requestFeaturePermissions(
    String featureName,
  ) async {
    final perms = _service.permissionsForFeature(featureName);
    final results = <DevicePermission, bool>{};
    for (final p in perms) {
      results[p] = await requestPermission(p);
    }
    return results;
  }

  /// Open settings for a specific permission.
  Future<void> openPermissionSettings(DevicePermission permission) async {
    final result = await _service.openSettings(permission);
    if (result.isFailure) {
      _emit(_state.copyWith(
        failure: CentralPermissionFailure.settings(
          permission: permission,
          action: 'open_settings_manually',
          cause: result.failureOrNull,
        ),
      ));
    }
  }

  /// Check all permission statuses (convenience alias for loadAllStatuses).
  Future<void> checkAllPermissions() => loadAllStatuses();

  /// Request all permissions sequentially.
  Future<void> requestAllPermissions() async {
    for (final p in DevicePermission.values) {
      await requestPermission(p);
    }
  }
}
