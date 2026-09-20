import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_assistant/l10n/app_localizations.dart';

import '../../core/theme/app_colors.dart';
import '../../core/providers/phase3_connection_points.dart' show navigationIndexProvider;

/// Floating bottom navigation bar — 3 items.
///
/// Items: Home (ماڵەوە), Chat (چات), Settings (ڕێکخستن)
///
/// Profile tab removed (was duplicate of Settings).
/// Dashboard removed from nav (VoiceScreen is now Home).
///
/// Visual: frosted glass pill shape floating above bottom of screen,
/// deep blur backdrop, active tab shown by violet/magenta glow.
class FloatingNavBar extends ConsumerWidget {
  const FloatingNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final l10n = S.of(context);

    final items = [
      _NavItem(
        icon: Icons.graphic_eq_rounded,
        label: l10n.navHome,
        index: 0,
      ),
      _NavItem(
        icon: Icons.chat_bubble_outline_rounded,
        label: l10n.navChat,
        index: 1,
      ),
      _NavItem(
        icon: Icons.settings_outlined,
        label: l10n.navSettings,
        index: 2,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.glassBackground.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items.map((item) {
                final isActive = currentIndex == item.index;
                return _NavButton(
                  icon: item.icon,
                  label: item.label,
                  isActive: isActive,
                  onTap: () {
                    ref.read(navigationIndexProvider.notifier).state = item.index;
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final int index;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? AppColors.violet.withValues(alpha: 0.2)
                    : Colors.transparent,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.violet.withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                size: 22,
                color: isActive
                    ? AppColors.violetLight
                    : AppColors.onBackground.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? AppColors.violetLight
                    : AppColors.onBackground.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}