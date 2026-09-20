// ───────────────────────────────────────────────────────────────────
// Step 5 – Runtime Permission Flows · Permission Rationale Sheet
// ───────────────────────────────────────────────────────────────────
// Kurdish Sorani RTL-first bottom sheet that explains WHY a permission
// is needed BEFORE the system dialog appears.
//
// Follows Android best practice: show rationale when shouldShowRationale
// is true (user denied once) or on first request for critical perms.
// ───────────────────────────────────────────────────────────────────

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

/// Kurdish Sorani rationale texts for each AURA permission.
/// These are shown BEFORE the system dialog to explain why the
/// permission is needed in natural, friendly Kurdish.
// Permission overrides == and hashCode, so it cannot be used as a
// const Map key (const_map_key_not_primitive_equality).  Use a
// non-const map instead.
final Map<ph.Permission, _RationaleText> _kurdishRationales = {
  ph.Permission.microphone: _RationaleText(
    title: 'میکرۆفۆن',
    body: 'بۆ ئەوەی بتوانم دەنگت ببیستم و وەڵامت بدەمەوە، پێویستیم بە میکرۆفۆنە. '
        'بەبێ ئەم ڕێگەیە ناتوانم قسەی تۆ بفام.',
    icon: Icons.mic_rounded,
  ),
  ph.Permission.camera: _RationaleText(
    title: 'کامێرا',
    body: 'بۆ ئەوەی بتوانم وێنە و شتی دەوروبەرت ببینم و تێبگەم، '
        'پێویستیم بە کامێرایە. هیچ وێنەیەک بێ ڕەزامەدید ناگوازرێتەوە.',
    icon: Icons.camera_alt_rounded,
  ),
  ph.Permission.notification: _RationaleText(
    title: 'ئاگاداری',
    body: 'بۆ ئەوەی بتوانم ئاگاداری و بیرخەرەوەت پێ بدەمێ، پێویستیم بە '
        'ڕێگەی ئاگاداریە. بەبێ ئەمە ناتوانم لە کاتی دڵخوازت ئاگادارت بکەمەوە.',
    icon: Icons.notifications_rounded,
  ),
  ph.Permission.systemAlertWindow: _RationaleText(
    title: 'پەنجەرەی سەرەوە',
    body: 'بۆ ئەوەی بتوانم وەک یاریدەدەر لە سەرەوەی ئەپەکانی تر '
        'بیرت بخەمەوە، پێویستیم بە ڕێگەی پەنجەرەی سەرەوەیە.',
    icon: Icons.layers_rounded,
  ),
  ph.Permission.storage: _RationaleText(
    title: 'بیرگە',
    body: 'بۆ ئەوەی بتوانم فایل و داتا لە بیرگەی ئامێرەکەت بخوێنمەوە '
        'یان پاشەکەوت بکەم، پێویستیم بە ڕێگەی بیرگەیە.',
    icon: Icons.sd_storage_rounded,
  ),
  ph.Permission.ignoreBatteryOptimizations: _RationaleText(
    title: 'بەتەریا',
    body: 'بۆ ئەوەی بتوانم لە پاشبنەمایدا بەردەوام بم و ئاگاداریت '
        'بکەمەوە، پێویستە بەتەریا بە باشی بەکاربهێنم.',
    icon: Icons.battery_charging_full_rounded,
  ),
  ph.Permission.location: _RationaleText(
    title: 'شوێن',
    body: 'بۆ ئەوەی بتوانم خزمەتگوزاری شوێنپێکەر پێشکەش بکەم، '
        'پێویستیم بە ڕێگەی شوێنە. شوێنی تۆ تەنها بۆ ئەو کردارە بەکاردێت.',
    icon: Icons.location_on_rounded,
  ),
  ph.Permission.scheduleExactAlarm: _RationaleText(
    title: 'ئاژەڵی تەواو',
    body: 'بۆ ئەوەی بتوانم ئاژەڵ بە کاتی تەواو ڕێکبخەم، پێویستیم بە '
        'ڕێگەی ئاژەڵی تەواوە. بەبێ ئەمە ئاژەڵەکان لە کاتی دروست نادەن.',
    icon: Icons.alarm_rounded,
  ),
};

class _RationaleText {
  final String title;
  final String body;
  final IconData icon;
  const _RationaleText({
    required this.title,
    required this.body,
    required this.icon,
  });
}

/// Shows a glassmorphism bottom sheet explaining why a permission is needed.
/// Returns `true` if the user taps "بەردەوام" (continue), `false` if dismissed.
Future<bool> showPermissionRationale(
  BuildContext context,
  ph.Permission permission,
) async {
  final rationale = _kurdishRationales[permission];
  if (rationale == null) return true; // unknown perm → skip rationale

  final result = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _RationaleSheet(
      permission: permission,
      rationale: rationale,
    ),
  );

  return result ?? false;
}

class _RationaleSheet extends StatelessWidget {
  final ph.Permission permission;
  final _RationaleText rationale;

  const _RationaleSheet({
    required this.permission,
    required this.rationale,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = S.of(context);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                crossAxisAlignment:
                    isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // ── Handle bar ────────────────────────────────────
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ── Icon ─────────────────────────────────────────
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      rationale.icon,
                      size: 28,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Title ────────────────────────────────────────
                  Text(
                    rationale.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  ),
                  const SizedBox(height: 8),

                  // ── Body ─────────────────────────────────────────
                  Text(
                    rationale.body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.6,
                    ),
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  ),
                  const SizedBox(height: 24),

                  // ── Actions ──────────────────────────────────────
                  Row(
                    textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(l10n.perm_not_now),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(l10n.perm_continue),
                        ),
                      ),
                    ],
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
