import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Theme-adaptive color tokens.
///
/// While [AppColors] defines static palette values, [AuraColors]
/// resolves the correct color based on [Brightness].
///
/// Usage:
/// ```dart
/// final c = AuraColors.of(context);
/// // or
/// final c = AuraColors.resolve(Brightness.dark);
/// ```
class AuraColors {
  AuraColors._();

  // ── Dark palette (original AURA identity) ──
  static const _darkBackground = AppColors.background;
  static const _darkCard = AppColors.card;
  static const _darkSecondary = AppColors.secondary;
  static const _darkOnBackground = AppColors.onBackground;
  static const _darkOnCard = AppColors.onCard;
  static const _darkHint = AppColors.hint;
  static const _darkBorder = AppColors.border;
  static const _darkDivider = AppColors.divider;

  // ── Light palette (AURA-branded light mode) ──
  static const Color _lightBackground = Color(0xFFF8FAFB);
  static const Color _lightCard = Color(0xFFFFFFFF);
  static const Color _lightSecondary = Color(0xFFEEF1F5);
  static const Color _lightOnBackground = Color(0xFF1A1D23);
  static const Color _lightOnCard = Color(0xFF374151);
  static const Color _lightHint = Color(0xFF9CA3AF);
  static const Color _lightBorder = Color(0xFFE5E7EB);
  static const Color _lightDivider = Color(0xFFE5E7EB);

  // ── Natural palette (earthy warm tones) ──
  static const Color _naturalBackground = Color(0xFFF5F0EB);
  static const Color _naturalCard = Color(0xFFFFFCF8);
  static const Color _naturalSecondary = Color(0xFFF0EBE3);
  static const Color _naturalOnBackground = Color(0xFF2D2926);
  static const Color _naturalOnCard = Color(0xFF5C554E);
  static const Color _naturalHint = Color(0xFF8C847D);
  static const Color _naturalBorder = Color(0xFFE0D8D0);
  static const Color _naturalDivider = Color(0xFFE0D8D0);
  static const Color _naturalAccent = Color(0xFF00897B); // Teal variant
  static const Color _naturalAccentLight = Color(0xFF4DB6AC);

  // ── Resolvers ──

  static Color background(Brightness b) =>
      b == Brightness.dark ? _darkBackground : _lightBackground;

  static Color card(Brightness b) =>
      b == Brightness.dark ? _darkCard : _lightCard;

  static Color secondary(Brightness b) =>
      b == Brightness.dark ? _darkSecondary : _lightSecondary;

  static Color onBackground(Brightness b) =>
      b == Brightness.dark ? _darkOnBackground : _lightOnBackground;

  static Color onCard(Brightness b) =>
      b == Brightness.dark ? _darkOnCard : _lightOnCard;

  static Color hint(Brightness b) =>
      b == Brightness.dark ? _darkHint : _lightHint;

  static Color border(Brightness b) =>
      b == Brightness.dark ? _darkBorder : _lightBorder;

  static Color divider(Brightness b) =>
      b == Brightness.dark ? _darkDivider : _lightDivider;

  /// Primary accent — cyan in dark/light, teal in natural.
  static Color accent(Brightness b) =>
      b == Brightness.dark ? AppColors.primary : AppColors.primary;

  static Color accentForTheme(AuraThemeVariant variant) {
    switch (variant) {
      case AuraThemeVariant.dark:
      case AuraThemeVariant.light:
        return AppColors.primary;
      case AuraThemeVariant.natural:
        return _naturalAccent;
    }
  }

  /// Context shorthand.
  static Color of(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// Accent color resolved from [BuildContext].
  /// Use instead of [accent] when you have a [BuildContext] but not a [Brightness].
  static Color accentOf(BuildContext context) =>
      accent(Theme.of(context).brightness);

  // ── Natural-specific accessors ──

  static const Color naturalBackground = _naturalBackground;
  static const Color naturalCard = _naturalCard;
  static const Color naturalSecondary = _naturalSecondary;
  static const Color naturalOnBackground = _naturalOnBackground;
  static const Color naturalOnCard = _naturalOnCard;
  static const Color naturalHint = _naturalHint;
  static const Color naturalBorder = _naturalBorder;
  static const Color naturalDivider = _naturalDivider;
  static const Color naturalAccent = _naturalAccent;
  static const Color naturalAccentLight = _naturalAccentLight;
}

/// Extended theme variants beyond just dark/light.
enum AuraThemeVariant { dark, light, natural }
