// ───────────────────────────────────────────────────────────────────
// Permissions Section Widget — Rebuilt with glass design
// ───────────────────────────────────────────────────────────────────
// RESTORED: DevicePermission.storage and DevicePermission.location
// are back in _CheckablePermissions — AURA has real features that
// need them (NavigationTool, MemoryType.location, VisionTool gallery,
// MediaTool, CameraService.pickImageFromGallery, etc.).
//
// storage is displayed as "Files & Media" in the UI with a modern
// Android permission mapping (READ_MEDIA_* on API 33+, with
// READ_EXTERNAL_STORAGE fallback on API ≤32).
//
// P2 FIX: overlay now maps to ph.Permission.systemAlertWindow (it exists!)
// via devicePermissionToPH(), so it's checked properly.
//
// P2 FIX: Special permissions (accessibility, overlay, assistant,
// screenCapture, batteryOptimization, exactAlarm) now use
// ContextualPermissionHelper for checking/requesting instead of
// falling back to ph.openAppSettings() for everything.
// ───────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'package:texo/l10n/app_localizations.dart';
import 'package:texo/features/device_integration/domain/models/permission_status.dart';
import 'package:texo/features/central_permissions/presentation/permission_status_card.dart';
import 'package:texo/core/permissions/contextual_permission_helper.dart';
import 'package:texo/core/theme/app_colors.dart';

/// Permissions that can be checked/requested via permission_handler.
///
/// RESTORED: storage and location are back — AURA has real features
/// that need them. storage is displayed as "Files & Media" in UI.
class _CheckablePermissions {
  static const list = <DevicePermission>[
    DevicePermission.microphone,
    DevicePermission.camera,
    DevicePermission.notification,
    DevicePermission.storage,
    DevicePermission.location,
    DevicePermission.batteryOptimization,
    DevicePermission.exactAlarm,
  ];
}

/// Permissions that require platform channel or system Settings.
///
/// P2 FIX: overlay moved here since it needs system dialog.
/// overlay IS checked via ph.Permission.systemAlertWindow now,
/// but requesting it requires the MANAGE_OVERLAY_PERMISSION intent.
class _SystemPermissions {
  static const list = <DevicePermission>[
    DevicePermission.accessibility,
    DevicePermission.overlay,
    DevicePermission.screenCapture,
    DevicePermission.assistant,
  ];
}

class PermissionsSection extends ConsumerStatefulWidget {
  const PermissionsSection({super.key});

  @override
  ConsumerState<PermissionsSection> createState() =>
      _PermissionsSectionState();
}

class _PermissionsSectionState extends ConsumerState<PermissionsSection>
    with WidgetsBindingObserver {
  Map<DevicePermission, PermissionStatus> _statuses = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAllStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user returns from a system Settings page (e.g. after choosing
    // AURA as the default digital assistant, or toggling accessibility /
    // overlay), re-read every status so the cards reflect the real state
    // instead of a stale value. This is the authoritative refresh: special
    // permissions are granted outside our process via startActivity, so we
    // cannot get a direct callback.
    if (state == AppLifecycleState.resumed && mounted) {
      _loadAllStatuses();
    }
  }

  Future<void> _loadAllStatuses() async {
    final statuses = <DevicePermission, PermissionStatus>{};
    final permHelper = ContextualPermissionHelper();

    // Checkable permissions — use permission_handler via devicePermissionToPH()
    for (final dp in _CheckablePermissions.list) {
      final phPerm = devicePermissionToPH(dp);
      if (phPerm != null) {
        final rawStatus = await phPerm.status;
        statuses[dp] = phStatusToLocal(rawStatus);
      } else {
        statuses[dp] = PermissionStatus.unknown;
      }
    }

    // System/special permissions — use ContextualPermissionHelper platform channel
    for (final dp in _SystemPermissions.list) {
      try {
        final status = await permHelper.checkSpecialPermission(dp);
        statuses[dp] = status;
      } catch (_) {
        // Fallback to permission_handler for overlay (it works now!)
        final phPerm = devicePermissionToPH(dp);
        if (phPerm != null) {
          final rawStatus = await phPerm.status;
          statuses[dp] = phStatusToLocal(rawStatus);
        } else {
          statuses[dp] = PermissionStatus.notRequested;
        }
      }
    }

    if (mounted) {
      setState(() {
        _statuses = statuses;
        _loading = false;
      });
    }
  }

  Future<void> _requestPermission(DevicePermission dp) async {
    final permHelper = ContextualPermissionHelper();

    // For system permissions, use the platform channel (opens Settings)
    if (_SystemPermissions.list.contains(dp)) {
      await permHelper.requestSpecialPermission(dp);
      // Give user time to toggle the setting
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadAllStatuses();
      return;
    }

    // For checkable permissions, use the full rationale flow
    final phPerm = devicePermissionToPH(dp);
    if (phPerm == null) {
      // Last resort — open app settings
      await ph.openAppSettings();
      await _loadAllStatuses();
      return;
    }

    await permHelper.requestSingleWithRationale(
      context: context,
      permission: phPerm,
      isCritical: true,
    );

    await _loadAllStatuses();
  }

  Future<void> _openSettings(DevicePermission dp) async {
    final permHelper = ContextualPermissionHelper();

    // For system permissions, use the platform channel (opens the specific Settings page)
    if (_SystemPermissions.list.contains(dp)) {
      await permHelper.requestSpecialPermission(dp);
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadAllStatuses();
      return;
    }

    // For checkable permissions, open app settings
    await ph.openAppSettings();
    await _loadAllStatuses();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.cyan,
          ),
        ),
      );
    }

    final checkableCards = _CheckablePermissions.list.map((dp) {
      final status = _statuses[dp] ?? PermissionStatus.unknown;
      return PermissionStatusCard(
        permission: dp,
        status: status,
        onRequest: status == PermissionStatus.granted
            ? null
            : () => _requestPermission(dp),
        onOpenSettings: status == PermissionStatus.permanentlyDenied
            ? () => _openSettings(dp)
            : null,
      );
    }).toList();

    final systemCards = _SystemPermissions.list.map((dp) {
      final status = _statuses[dp] ?? PermissionStatus.notRequested;
      return PermissionStatusCard(
        permission: dp,
        status: status,
        onRequest: () => _openSettings(dp),
        onOpenSettings: () => _openSettings(dp),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Checkable permissions
        ...checkableCards,

        // Divider between sections
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Container(
            height: 0.5,
            color: AppColors.glassBorder,
          ),
        ),

        // System permissions subheader
        Padding(
          padding: EdgeInsets.fromLTRB(
            isRtl ? 0 : 20,
            4,
            isRtl ? 20 : 0,
            8,
          ),
          child: Text(
            s.perm_open_settings,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.hint,
            ),
          ),
        ),

        // System permissions
        ...systemCards,

        const SizedBox(height: 8),
      ],
    );
  }
}