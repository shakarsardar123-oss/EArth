// ───────────────────────────────────────────────────────────────────
// Central Permissions · Status Card — Rebuilt with glass design
// ───────────────────────────────────────────────────────────────────
// Uses GlassCard + BackdropFilter instead of Material Card.
// Matches AURA new design language: dark bg, glass border, cyan accent.
// ───────────────────────────────────────────────────────────────────

import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:texo/l10n/app_localizations.dart';
import 'package:texo/features/device_integration/domain/models/permission_status.dart';
import 'package:texo/features/central_permissions/domain/models/permission_explanation.dart';
import 'package:texo/core/theme/app_colors.dart';
import 'package:texo/presentation/widgets/glass_dialog.dart';

class PermissionStatusCard extends StatelessWidget {
  final DevicePermission permission;
  final PermissionStatus status;
  final VoidCallback? onRequest;
  final VoidCallback? onOpenSettings;

  const PermissionStatusCard({
    super.key,
    required this.permission,
    required this.status,
    this.onRequest,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final explanation = PermissionExplanation.defaults[permission];
    final isCritical = explanation?.isCritical ?? false;
    final s = S.of(context);

    final statusColor = switch (status) {
      PermissionStatus.granted => Colors.green,
      PermissionStatus.denied => Colors.orange,
      PermissionStatus.permanentlyDenied => Colors.red,
      PermissionStatus.notRequested => Colors.grey,
      PermissionStatus.unknown => Colors.grey,
    };

    final statusLabel = switch (status) {
      PermissionStatus.granted => s.perm_granted,
      PermissionStatus.denied => s.perm_denied,
      PermissionStatus.permanentlyDenied => s.perm_permanently_denied,
      PermissionStatus.notRequested => s.perm_not_requested,
      PermissionStatus.unknown => s.perm_unknown,
    };

    final permTitle = switch (permission) {
      DevicePermission.accessibility => s.perm_accessibility_title,
      DevicePermission.overlay => s.perm_overlay_title,
      DevicePermission.screenCapture => s.perm_screen_capture_title,
      DevicePermission.microphone => s.perm_microphone_title,
      DevicePermission.camera => s.perm_camera_title,
      DevicePermission.storage => s.perm_storage_title,
      DevicePermission.notification => s.perm_notification_title,
      DevicePermission.batteryOptimization => s.perm_battery_title,
      DevicePermission.assistant => s.perm_assistant_title,
      DevicePermission.location => s.perm_location_title,
      DevicePermission.exactAlarm => s.perm_exact_alarm_title,
    };

    final iconData = switch (permission) {
      DevicePermission.accessibility => Icons.accessibility_new,
      DevicePermission.overlay => Icons.layers,
      DevicePermission.screenCapture => Icons.screenshot_monitor,
      DevicePermission.microphone => Icons.mic,
      DevicePermission.camera => Icons.camera_alt,
      DevicePermission.storage => Icons.folder,
      DevicePermission.notification => Icons.notifications,
      DevicePermission.batteryOptimization => Icons.battery_charging_full,
      DevicePermission.assistant => Icons.assistant,
      DevicePermission.location => Icons.location_on,
      DevicePermission.exactAlarm => Icons.alarm,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isCritical
                    ? statusColor.withOpacity(0.4)
                    : AppColors.glassBorder,
                width: isCritical ? 1 : 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  // Status dot
                  Container(
                    width: 10,
                    height: 10,
                    margin: EdgeInsets.only(
                      right: isRtl ? 0 : 10,
                      left: isRtl ? 10 : 0,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.3),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),

                  // Icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.violet.withOpacity(0.1),
                      border: Border.all(
                        color: AppColors.violetLight.withOpacity(0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Icon(iconData, size: 18, color: AppColors.cyan),
                  ),

                  const SizedBox(width: 12),

                  // Title + status
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Row(
                          textDirection:
                              isRtl ? TextDirection.rtl : TextDirection.ltr,
                          children: [
                            Text(
                              permTitle,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onBackground,
                              ),
                            ),
                            if (isCritical) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.red.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.red.withOpacity(0.3),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  s.perm_critical,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.red,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action button
                  if (status == PermissionStatus.granted)
                    Icon(Icons.check_circle, color: Colors.green, size: 24)
                  else if (status == PermissionStatus.permanentlyDenied)
                    GlassButton(
                      label: s.perm_open_settings,
                      variant: GlassButtonVariant.text,
                      onPressed: onOpenSettings,
                    )
                  else
                    GlassButton(
                      label: s.perm_request,
                      variant: GlassButtonVariant.filled,
                      onPressed: onRequest,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
