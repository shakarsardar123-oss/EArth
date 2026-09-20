// ───────────────────────────────────────────────────────────────────
// Step 5 – Runtime Permission Flows · Contextual Permission Helper
// ───────────────────────────────────────────────────────────────────
// High-level helper that wraps PermissionService with:
//   1. Rationale sheet (show before system dialog when appropriate)
//   2. Permanent-denial → open system settings flow
//   3. Multi-permission support (e.g., VisionScreen needs camera + mic)
//   4. Platform channel for special permissions (accessibility, overlay, assistant)
//
// P2 FIX: Replaced deprecated ph.Permission.storage with
//   ph.Permission.photos / ph.Permission.videos on Android 13+.
//   Added platform channel calls for special permissions.
// ───────────────────────────────────────────────────────────────────

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'permission_service.dart';
import 'permission_rationale_sheet.dart';
import '../errors/result.dart';
import '../errors/failures.dart';
import '../../features/device_integration/domain/models/permission_status.dart';
import '../../core/device/device_channel.dart';
import '../../core/device/android_device_channel.dart';
import '../../presentation/providers/app_providers.dart'
    show deviceChannelProvider;

/// Maps a [DevicePermission] to the corresponding [ph.Permission].
///
/// P2 FIX: [DevicePermission.storage] now maps to appropriate scoped
/// storage permissions based on Android API level, not the deprecated
/// ph.Permission.storage.
///
/// Special permissions (accessibility, overlay, screenCapture, assistant)
/// have no direct ph.Permission equivalent — they return null and are
/// handled via platform channels.
ph.Permission? devicePermissionToPH(DevicePermission dp) {
  switch (dp) {
    case DevicePermission.microphone:
      return ph.Permission.microphone;
    case DevicePermission.camera:
      return ph.Permission.camera;
    case DevicePermission.notification:
      return ph.Permission.notification;
    case DevicePermission.storage:
      // Modern Android approach: use granular media permissions on
      // API 33+ (photos/videos/audio), fallback to storage on API ≤32.
      // Since permission_handler Permission.photos covers READ_MEDIA_IMAGES
      // on Android 13+ and falls back to READ_EXTERNAL_STORAGE on older,
      // we return Permission.photos as the primary mapping.
      // The Manifest declares all needed permissions; this one is used
      // for the runtime request dialog.
      return ph.Permission.photos;
    case DevicePermission.batteryOptimization:
      return ph.Permission.ignoreBatteryOptimizations;
    case DevicePermission.location:
      return ph.Permission.location;
    case DevicePermission.exactAlarm:
      return ph.Permission.scheduleExactAlarm;
    case DevicePermission.overlay:
      // P2 FIX: ph.Permission.systemAlertWindow EXISTS and maps to
      // Manifest SYSTEM_ALERT_WINDOW. This lets permission_handler check
      // the status. The request still needs to go through the platform
      // channel (ACTION_MANAGE_OVERLAY_PERMISSION), but status checking
      // works directly.
      return ph.Permission.systemAlertWindow;
    case DevicePermission.accessibility:
    case DevicePermission.screenCapture:
    case DevicePermission.assistant:
      return null; // platform-channel only
  }
}

/// Maps a [ph.PermissionStatus] to our [PermissionStatus].
PermissionStatus phStatusToLocal(ph.PermissionStatus status) {
  if (status.isGranted) return PermissionStatus.granted;
  if (status.isDenied) return PermissionStatus.denied;
  if (status.isPermanentlyDenied) return PermissionStatus.permanentlyDenied;
  if (status.isLimited) return PermissionStatus.granted; // treat limited as granted
  return PermissionStatus.unknown;
}

/// Outcome of a contextual permission request.
class ContextualPermissionOutcome {
  /// All requested permissions were granted.
  final bool allGranted;

  /// At least one permission was permanently denied.
  final bool hasPermanentlyDenied;

  /// Per-permission results.
  final Map<ph.Permission, bool> results;

  const ContextualPermissionOutcome({
    required this.allGranted,
    required this.hasPermanentlyDenied,
    required this.results,
  });
}

/// Wraps [PermissionService] with rationale UI and settings redirect.
///
/// P2 FIX: Also supports special permissions (accessibility, overlay,
/// assistant, screenCapture) via platform channels.
///
/// Usage:
/// ```dart
/// final helper = ContextualPermissionHelper();
/// final outcome = await helper.requestWithRationale(
///   context: context,
///   permissions: [ph.Permission.microphone],
///   isCritical: true,
/// );
/// if (outcome.allGranted) { ... }
/// ```
class ContextualPermissionHelper {
  final PermissionService _service;

  /// Platform channel for special permission operations.
  static const MethodChannel _channel =
      MethodChannel('com.aura.device/permissions');

  ContextualPermissionHelper([PermissionService? service])
      : _service = service ?? PermissionService();

  /// Requests one or more permissions with the full rationale → request →
  /// permanent-denial → settings flow.
  ///
  /// For each permission:
  ///  1. Check if already granted → skip.
  ///  2. If [isCritical] or shouldShowRationale is true → show rationale sheet.
  ///  3. If user dismisses rationale → mark denied.
  ///  4. Request via system dialog.
  ///  5. If permanently denied → offer to open settings.
  Future<ContextualPermissionOutcome> requestWithRationale({
    required BuildContext context,
    required List<ph.Permission> permissions,
    bool isCritical = false,
  }) async {
    final results = <ph.Permission, bool>{};
    bool anyPermanentlyDenied = false;

    for (final permission in permissions) {
      // 1. Already granted?
      final alreadyGranted = await _service.isPermissionGranted(permission);
      if (alreadyGranted) {
        results[permission] = true;
        continue;
      }

      // 2. Show rationale for critical permissions or when the user
      //    previously denied (but not permanently).
      final shouldShow = isCritical ||
          await permission.shouldShowRequestRationale;

      if (shouldShow && context.mounted) {
        final userWantsToContinue =
            await showPermissionRationale(context, permission);
        if (!userWantsToContinue) {
          results[permission] = false;
          continue;
        }
      }

      // 3. Request via system dialog.
      if (!context.mounted) {
        results[permission] = false;
        continue;
      }

      final result = await _service.requestPermission(permission);
      final granted = result.isSuccess && result.getOrElse(() => false);
      results[permission] = granted;

      // 4. If permanently denied, offer to open settings.
      if (!granted && context.mounted) {
        final permanentlyDenied =
            await _service.isPermissionPermanentlyDenied(permission);
        if (permanentlyDenied) {
          anyPermanentlyDenied = true;
          final opened = await _service.openAppSettings();
          if (!opened) {
            // If settings can't be opened, at least we tried.
          }
        }
      }
    }

    return ContextualPermissionOutcome(
      allGranted: results.values.every((v) => v),
      hasPermanentlyDenied: anyPermanentlyDenied,
      results: results,
    );
  }

  /// Convenience for requesting a single permission.
  ///
  /// Returns true if granted, false otherwise.
  /// Automatically opens settings on permanent denial.
  Future<bool> requestSingleWithRationale({
    required BuildContext context,
    required ph.Permission permission,
    bool isCritical = false,
  }) async {
    final outcome = await requestWithRationale(
      context: context,
      permissions: [permission],
      isCritical: isCritical,
    );
    return outcome.allGranted;
  }

  // ─── Special Permission Helpers (Platform Channel) ─────────────────

  /// Checks if a special permission is granted via platform channel.
  ///
  /// Used for: accessibility, overlay, assistant, screenCapture.
  Future<PermissionStatus> checkSpecialPermission(
      DevicePermission permission) async {
    if (!Platform.isAndroid) return PermissionStatus.unknown;

    try {
      final result = await _channel.invokeMethod<bool>(
        'checkPermission',
        {'permission': permission.name},
      );
      return result == true
          ? PermissionStatus.granted
          : PermissionStatus.denied;
    } on PlatformException {
      return PermissionStatus.unknown;
    } on MissingPluginException {
      // Native handler not yet implemented — don't crash
      return PermissionStatus.unknown;
    }
  }

  /// Requests a special permission via platform channel.
  ///
  /// For accessibility/overlay, this opens the relevant Android settings page.
  /// For assistant, this opens the Default Assistant settings page.
  Future<PermissionStatus> requestSpecialPermission(
      DevicePermission permission) async {
    if (!Platform.isAndroid) return PermissionStatus.unknown;

    try {
      final result = await _channel.invokeMethod<bool>(
        'requestPermission',
        {'permission': permission.name},
      );
      return result == true
          ? PermissionStatus.granted
          : PermissionStatus.denied;
    } on PlatformException {
      return PermissionStatus.unknown;
    } on MissingPluginException {
      // Fallback: try opening app settings at least
      await _service.openAppSettings();
      return PermissionStatus.unknown;
    }
  }
}
