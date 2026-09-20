import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_assistant/l10n/app_localizations.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_provider.dart';
import '../providers/app_providers.dart';
import 'glass_card.dart';

/// Theme selector with glass preview cards for dark/light/natural.
///
/// Rebuilt with new design system: GlassCard with glow on selection,
/// dark backgrounds, 28px radius, accent colors for selected state.
class ThemeSelector extends ConsumerWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final themeMode = ref.watch(overriddenThemeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _ThemeOption(
            label: l10n.themeDark,
            icon: Icons.dark_mode_outlined,
            isSelected: themeMode == AuraThemeMode.dark,
            previewColor: const Color(0xFF1A1A2E),
            onTap: () => ref.read(overriddenThemeProvider.notifier).setTheme(AuraThemeMode.dark),
          ),
          SizedBox(width: 8),
          _ThemeOption(
            label: l10n.themeLight,
            icon: Icons.light_mode_outlined,
            isSelected: themeMode == AuraThemeMode.light,
            previewColor: const Color(0xFFF8F9FA),
            onTap: () => ref.read(overriddenThemeProvider.notifier).setTheme(AuraThemeMode.light),
          ),
          SizedBox(width: 8),
          _ThemeOption(
            label: l10n.themeNatural,
            icon: Icons.nature_outlined,
            isSelected: themeMode == AuraThemeMode.natural,
            previewColor: const Color(0xFFF5F0E8),
            accentColor: const Color(0xFF00897B),
            onTap: () => ref.read(overriddenThemeProvider.notifier).setTheme(AuraThemeMode.natural),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.previewColor,
    required this.onTap,
    this.accentColor,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color previewColor;
  final Color? accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.violet;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          showGlow: isSelected,
          glowColor: accent.withOpacity(0.25),
          borderColor: isSelected
              ? accent.withOpacity(0.5)
              : AppColors.glassBorder,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mini preview rectangle
              Container(
                width: 40,
                height: 28,
                decoration: BoxDecoration(
                  color: previewColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.glassBorder,
                    width: 0.5,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 14,
                    height: 4,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Icon(
                icon,
                size: 18,
                color: isSelected ? accent : AppColors.hint,
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? accent : AppColors.hint,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
