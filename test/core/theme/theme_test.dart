import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/theme/theme_provider.dart';
import 'package:aura_assistant/core/theme/app_colors.dart';
import 'package:aura_assistant/core/theme/app_text_styles.dart';

void main() {
  group('AuraThemeMode', () {
    test('has exactly four values', () {
      expect(AuraThemeMode.values.length, 4);
      expect(
        AuraThemeMode.values,
        containsAll([AuraThemeMode.dark, AuraThemeMode.light, AuraThemeMode.natural, AuraThemeMode.system]),
      );
    });

    test('natural maps to ThemeMode.light', () {
      expect(AuraThemeMode.natural.toThemeMode(), ThemeMode.light);
    });

    test('dark maps to ThemeMode.dark', () {
      expect(AuraThemeMode.dark.toThemeMode(), ThemeMode.dark);
    });

    test('light maps to ThemeMode.light', () {
      expect(AuraThemeMode.light.toThemeMode(), ThemeMode.light);
    });

    test('system maps to ThemeMode.system', () {
      expect(AuraThemeMode.system.toThemeMode(), ThemeMode.system);
    });
  });

  group('AppColors', () {
    test('background is #0B0E14', () {
      expect(AppColors.background, const Color(0xFF0B0E14));
    });

    test('card is #151A23', () {
      expect(AppColors.card, const Color(0xFF151A23));
    });

    test('secondary is #111720', () {
      expect(AppColors.secondary, const Color(0xFF111720));
    });

    test('primary is cyan #00E5FF', () {
      expect(AppColors.primary, const Color(0xFF00E5FF));
      expect(AppColors.primary, AppColors.cyan);
    });

    test('cyan is #00E5FF', () {
      expect(AppColors.cyan, const Color(0xFF00E5FF));
    });

    test('blue is #448AFF', () {
      expect(AppColors.blue, const Color(0xFF448AFF));
    });

    test('error is red', () {
      expect(AppColors.error, AppColors.red);
    });

    test('surface equals card', () {
      expect(AppColors.surface, AppColors.card);
    });

    test('onSurface equals onCard', () {
      expect(AppColors.onSurface, AppColors.onCard);
    });

    test('border equals divider', () {
      expect(AppColors.border, AppColors.divider);
    });

    test('onBackground is #E1E4EA', () {
      expect(AppColors.onBackground, const Color(0xFFE1E4EA));
    });

    test('onCard is #C9CDD4', () {
      expect(AppColors.onCard, const Color(0xFFC9CDD4));
    });

    test('hint is #6B7280', () {
      expect(AppColors.hint, const Color(0xFF6B7280));
    });

    test('border is #1E2533', () {
      expect(AppColors.border, const Color(0xFF1E2533));
    });
  });

  group('AppTextStyles', () {
    test('headline1 has fontSize 32 and bold weight', () {
      expect(AppTextStyles.headline1.fontSize, 32);
      expect(AppTextStyles.headline1.fontWeight, FontWeight.bold);
    });

    test('headline1 color is onBackground', () {
      expect(AppTextStyles.headline1.color, AppColors.onBackground);
    });

    test('headline1 has letterSpacing -0.5', () {
      expect(AppTextStyles.headline1.letterSpacing, -0.5);
    });

    test('subtitle1 has fontSize 20 and w600 weight', () {
      expect(AppTextStyles.subtitle1.fontSize, 20);
      expect(AppTextStyles.subtitle1.fontWeight, FontWeight.w600);
    });

    test('body2 has fontSize 14', () {
      expect(AppTextStyles.body2.fontSize, 14);
    });

    test('body2 color is onCard', () {
      expect(AppTextStyles.body2.color, AppColors.onCard);
    });

    test('caption has fontSize 11', () {
      expect(AppTextStyles.caption.fontSize, 11);
    });

    test('caption color is hint', () {
      expect(AppTextStyles.caption.color, AppColors.hint);
    });

    test('caption has letterSpacing 0.5', () {
      expect(AppTextStyles.caption.letterSpacing, 0.5);
    });
  });
}
