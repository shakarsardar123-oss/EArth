// ───────────────────────────────────────────────────────────────────
// Step 16 – Central Permissions · Domain · CentralPermissionFailure
// ───────────────────────────────────────────────────────────────────
// Failure type for central permission operations.
// Follows the pattern from DeviceIntegrationFailure:
//   phase enum + factory constructors + phase/message/action/cause.
// ───────────────────────────────────────────────────────────────────

import 'package:texo/core/errors/result.dart';
import 'package:texo/features/device_integration/domain/models/permission_status.dart';

/// Phases during which a central-permission operation can fail.
enum CentralPermissionFailurePhase {
  /// Checking the current status of a permission.
  check,

  /// Showing a rationale / explanation to the user.
  explanation,

  /// The actual system permission request.
  request,

  /// Verifying a permission after it was allegedly granted.
  verify,

  /// Opening the system settings page.
  settings,

  /// A general / unknown failure.
  unknown,
}

/// Immutable failure for central-permission operations.
///
/// Follows the same pattern as [DeviceIntegrationFailure].
class CentralPermissionFailure {
  final CentralPermissionFailurePhase phase;
  final String message;
  final String? action;
  final Object? cause;

  const CentralPermissionFailure._({
    required this.phase,
    required this.message,
    this.action,
    this.cause,
  });

  // ── Factory constructors ─────────────────────────────────────────

  /// Failed while checking a permission's current status.
  factory CentralPermissionFailure.check({
    required DevicePermission permission,
    String? action,
    Object? cause,
  }) = _CheckFailure;

  /// Failed while showing the rationale/explanation sheet.
  factory CentralPermissionFailure.explanation({
    required DevicePermission permission,
    String? action,
    Object? cause,
  }) = _ExplanationFailure;

  /// The system request was denied by the user.
  factory CentralPermissionFailure.request({
    required DevicePermission permission,
    required PermissionStatus status,
    String? action,
    Object? cause,
  }) = _RequestFailure;

  /// Post-request verification discovered the permission is still not
  /// granted (possibly permanently denied).
  factory CentralPermissionFailure.verify({
    required DevicePermission permission,
    required PermissionStatus status,
    String? action,
    Object? cause,
  }) = _VerifyFailure;

  /// Could not open or navigate to the system settings page.
  factory CentralPermissionFailure.settings({
    required DevicePermission permission,
    String? action,
    Object? cause,
  }) = _SettingsFailure;

  /// An unexpected / unclassifiable failure.
  factory CentralPermissionFailure.unknown({
    required String message,
    String? action,
    Object? cause,
  }) = _UnknownFailure;

  // ── Convenience ──────────────────────────────────────────────────

  /// Whether the permission was permanently denied (user checked
  /// "Don't ask again" on Android).
  bool get isPermanentlyDenied =>
      (this is _RequestFailure &&
          (this as _RequestFailure).status ==
              PermissionStatus.permanentlyDenied) ||
      (this is _VerifyFailure &&
          (this as _VerifyFailure).status ==
              PermissionStatus.permanentlyDenied);

  /// The specific permission involved, if available.
  DevicePermission? get permission =>
      this is _PermissionCarryingFailure
          ? (this as _PermissionCarryingFailure).permission
          : null;

  @override
  String toString() =>
      'CentralPermissionFailure(phase: $phase, message: $message)';
}

// ── Private subtypes ────────────────────────────────────────────────

mixin _PermissionCarryingFailure on CentralPermissionFailure {
  @override
  DevicePermission get permission;
}

mixin _StatusCarryingFailure on CentralPermissionFailure {
  PermissionStatus get status;
}

class _CheckFailure extends CentralPermissionFailure
    with _PermissionCarryingFailure {
  @override
  final DevicePermission permission;
  _CheckFailure({required this.permission, String? action, Object? cause})
      : super._(
          phase: CentralPermissionFailurePhase.check,
          message: 'Failed to check status of $permission',
          action: action,
          cause: cause,
        );
}

class _ExplanationFailure extends CentralPermissionFailure
    with _PermissionCarryingFailure {
  @override
  final DevicePermission permission;
  _ExplanationFailure(
      {required this.permission, String? action, Object? cause})
      : super._(
          phase: CentralPermissionFailurePhase.explanation,
          message: 'Failed to show rationale for $permission',
          action: action,
          cause: cause,
        );
}

class _RequestFailure extends CentralPermissionFailure
    with _PermissionCarryingFailure, _StatusCarryingFailure {
  @override
  final DevicePermission permission;
  @override
  final PermissionStatus status;
  _RequestFailure({
    required this.permission,
    required this.status,
    String? action,
    Object? cause,
  }) : super._(
          phase: CentralPermissionFailurePhase.request,
          message: 'Permission request for $permission returned $status',
          action: action,
          cause: cause,
        );
}

class _VerifyFailure extends CentralPermissionFailure
    with _PermissionCarryingFailure, _StatusCarryingFailure {
  @override
  final DevicePermission permission;
  @override
  final PermissionStatus status;
  _VerifyFailure({
    required this.permission,
    required this.status,
    String? action,
    Object? cause,
  }) : super._(
          phase: CentralPermissionFailurePhase.verify,
          message: 'Verification of $permission found status $status',
          action: action,
          cause: cause,
        );
}

class _SettingsFailure extends CentralPermissionFailure
    with _PermissionCarryingFailure {
  @override
  final DevicePermission permission;
  _SettingsFailure({required this.permission, String? action, Object? cause})
      : super._(
          phase: CentralPermissionFailurePhase.settings,
          message: 'Failed to open settings for $permission',
          action: action,
          cause: cause,
        );
}

class _UnknownFailure extends CentralPermissionFailure {
  _UnknownFailure({required String message, String? action, Object? cause})
      : super._(
          phase: CentralPermissionFailurePhase.unknown,
          message: message,
          action: action,
          cause: cause,
        );
}

/// Type alias following the project convention
/// (cf. DeviceIntegrationResult<T>).
typedef CentralPermissionResult<T> = Result<T, CentralPermissionFailure>;
