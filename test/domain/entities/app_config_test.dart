import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/domain/entities/app_config.dart';

void main() {
  group('AppConfig', () {
    test('creates with required fields and defaults', () {
      const config = AppConfig(
        themeMode: 'dark',
        localeCode: 'ku',
      );
      expect(config.themeMode, 'dark');
      expect(config.localeCode, 'ku');
      expect(config.agentId, 'aura');
      expect(config.onboardingCompleted, isFalse);
      expect(config.version, 1);
    });

    test('creates with all custom fields', () {
      const config = AppConfig(
        themeMode: 'light',
        localeCode: 'en',
        agentId: 'custom-agent',
        onboardingCompleted: true,
        version: 2,
      );
      expect(config.themeMode, 'light');
      expect(config.localeCode, 'en');
      expect(config.agentId, 'custom-agent');
      expect(config.onboardingCompleted, isTrue);
      expect(config.version, 2);
    });

    test('copyWith overrides specified fields', () {
      const original = AppConfig(
        themeMode: 'dark',
        localeCode: 'ku',
      );
      final copied = original.copyWith(
        themeMode: 'light',
        onboardingCompleted: true,
      );
      expect(copied.themeMode, 'light');
      expect(copied.localeCode, 'ku');
      expect(copied.agentId, 'aura');
      expect(copied.onboardingCompleted, isTrue);
    });

    test('copyWith with no arguments returns identical copy', () {
      const original = AppConfig(
        themeMode: 'dark',
        localeCode: 'en',
        agentId: 'agent1',
        onboardingCompleted: true,
        version: 3,
      );
      final copied = original.copyWith();
      expect(copied.themeMode, original.themeMode);
      expect(copied.localeCode, original.localeCode);
      expect(copied.agentId, original.agentId);
      expect(copied.onboardingCompleted, original.onboardingCompleted);
      expect(copied.version, original.version);
    });
  });
}
