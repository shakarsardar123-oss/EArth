import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Centralized text styles for the AURA theme.
///
/// Provides both static [TextStyle] constants (for simple use cases)
/// and context-aware methods (for theme-adaptive styles).
///
/// **Prefer context-aware methods** in all Phase 2+ widgets
/// so colors adapt to dark/light/natural themes automatically.
class AppTextStyles {
  AppTextStyles._();

  // ── Static text styles (kept for backward compat, use dark palette) ──

  /// 32 px bold – used for the AURA logo heading.
  static const TextStyle headline1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.onBackground,
    letterSpacing: -0.5,
  );

  /// 20 px semi-bold – used for subtitles and app bar titles.
  static const TextStyle subtitle1 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.onBackground,
  );

  /// 14 px regular – used for body text and status chip values.
  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    color: AppColors.onCard,
  );

  /// 11 px small – used for captions and subtle labels.
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    color: AppColors.hint,
    letterSpacing: 0.5,
  );

  // ── Context-aware methods (theme-adaptive, prefer these) ──

  static TextStyle headlineLarge(BuildContext context) {
    return Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ) ??
        headline1;
  }

  static TextStyle headlineMedium(BuildContext context) {
    return Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.onBackground);
  }

  static TextStyle titleLarge(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ) ??
        subtitle1;
  }

  static TextStyle titleMedium(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium ??
        const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.onCard);
  }

  static TextStyle bodyLarge(BuildContext context) {
    return Theme.of(context).textTheme.bodyLarge ??
        const TextStyle(fontSize: 16, color: AppColors.onBackground);
  }

  static TextStyle bodyMedium(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium ?? body2;
  }

  static TextStyle labelLarge(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onBackground);
  }

  static TextStyle labelSmall(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 0.5,
        ) ??
        caption;
  }

  /// Accent-colored headline for AURA branding (uses primary color).
  static TextStyle auraLogo(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.bold,
      color: color,
      letterSpacing: 4,
    );
  }

  /// Accent-colored subtitle.
  static TextStyle accentSubtitle(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }
}
