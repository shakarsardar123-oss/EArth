import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../errors/failures.dart';
import '../errors/result.dart';
import 'permission_rationale_sheet.dart';

/// Service for managing runtime permissions.
class PermissionService {
  PermissionService();

  /// Requests a single permission and returns the result.
  Future<Result<bool, PermissionFailure>> requestPermission(ph.Permission permission) async {
    try {
      final status = await permission.request();

      if (status.isGranted) {
        return const Result.success(true);
      }

      if (status.isPermanentlyDenied) {
        return Result.failure(PermissionFailure(
          message: 'Permission ${permission.toString()} permanently denied. Please enable it in app settings.',
          code: 'PERMISSION_PERMANENTLY_DENIED',
          permission: permission.toString(),
        ));
      }

      return Result.failure(PermissionFailure(
        message: 'Permission ${permission.toString()} denied',
        code: 'PERMISSION_DENIED',
        permission: permission.toString(),
      ));
    } catch (e) {
      return Result.failure(PermissionFailure(
        message: 'Failed to request permission: $e',
        code: 'PERMISSION_ERROR',
        permission: permission.toString(),
      ));
    }
  }

  /// Checks if a permission is currently granted.
  Future<bool> isPermissionGranted(ph.Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }

  /// Checks if a permission is permanently denied.
  Future<bool> isPermissionPermanentlyDenied(ph.Permission permission) async {
    final status = await permission.status;
    return status.isPermanentlyDenied;
  }

  /// Opens the app's system settings page.
  Future<bool> openAppSettings() async {
    return ph.openAppSettings();
  }

  /// Requests all permissions needed for AURA to function.
  Future<Map<ph.Permission, bool>> requestAllRequiredPermissions() async {
    final permissions = <ph.Permission, bool>{};

    // Microphone for speech recognition
    final mic = await requestPermission(ph.Permission.microphone);
    permissions[ph.Permission.microphone] = mic.isSuccess && mic.getOrElse(() => false);

    return permissions;
  }

  /// Requests a permission with rationale flow:
  ///   1. If shouldShowRationale is true (or [forceRationale] is true),
  ///      show the Kurdish rationale bottom sheet first.
  ///   2. If the user dismisses the rationale, return false.
  ///   3. Request the permission via the system dialog.
  ///   4. If permanently denied, optionally open system settings.
  ///
  /// Returns [Result.success] with true if granted, false if user
  /// dismissed rationale; [Result.failure] on denial or error.
  Future<Result<bool, PermissionFailure>> requestWithRationale(
    ph.Permission permission, {
    BuildContext? context,
    bool forceRationale = false,
  }) async {
    // Show rationale if requested or if the system says we should.
    // shouldShowRequestRationale is from permission_handler's
    // PermissionActions extension.  On Android it returns true when
    // the user previously denied (soft denial).  On iOS: always false.
    final shouldShow = forceRationale ||
        (await permission.shouldShowRequestRationale);

    if (shouldShow && context != null && context.mounted) {
      final userContinue =
          await showPermissionRationale(context, permission);
      if (!userContinue) {
        return Result.failure(PermissionFailure(
          message: 'User dismissed rationale for ${permission.toString()}',
          code: 'PERMISSION_RATIONALE_DISMISSED',
          permission: permission.toString(),
        ));
      }
    }

    // Now request via system dialog.
    final result = await requestPermission(permission);

    // If permanently denied, open settings if context is available.
    if (result.isFailure && context != null && context.mounted) {
      final permanentlyDenied =
          await isPermissionPermanentlyDenied(permission);
      if (permanentlyDenied) {
        await openAppSettings();
      }
    }

    return result;
  }
}
