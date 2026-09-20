import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/data/models/app_config_model.dart';
import 'package:aura_assistant/domain/entities/app_config.dart';

void main() {
  group('AppConfigModel', () {
    final testJson = <String, dynamic>{
      'theme_mode': 'dark',
      'locale_code': 'ku',
      'agent_id': 'aura',
      'onboarding_completed': false,
      'version': 1,
    };

    test('fromJson creates correct model', () {
      final model = AppConfigModel.fromJson(testJson);
      expect(model.themeMode, 'dark');
      expect(model.localeCode, 'ku');
      expect(model.agentId, 'aura');
      expect(model.onboardingCompleted, isFalse);
      expect(model.version, 1);
    });

    test('toJson produces correct map with snake_case keys', () {
      const model = AppConfigModel(
        themeMode: 'dark',
        localeCode: 'ku',
        agentId: 'aura',
        onboardingCompleted: false,
        version: 1,
      );
      final json = model.toJson();
      expect(json['theme_mode'], 'dark');
      expect(json['locale_code'], 'ku');
      expect(json['agent_id'], 'aura');
      expect(json['onboarding_completed'], isFalse);
      expect(json['version'], 1);
    });

    test('toEntity converts to AppConfig correctly', () {
      final model = AppConfigModel.fromJson(testJson);
      final entity = model.toEntity();
      expect(entity, isA<AppConfig>());
      expect(entity.themeMode, model.themeMode);
      expect(entity.localeCode, model.localeCode);
      expect(entity.agentId, model.agentId);
      expect(entity.onboardingCompleted, model.onboardingCompleted);
      expect(entity.version, model.version);
    });

    test('fromEntity creates correct model', () {
      const entity = AppConfig(
        themeMode: 'light',
        localeCode: 'en',
        agentId: 'custom',
        onboardingCompleted: true,
        version: 3,
      );
      final model = AppConfigModel.fromEntity(entity);
      expect(model.themeMode, 'light');
      expect(model.localeCode, 'en');
      expect(model.agentId, 'custom');
      expect(model.onboardingCompleted, isTrue);
      expect(model.version, 3);
    });

    test('round-trip: fromJson -> toEntity -> fromEntity -> toJson preserves data', () {
      final model1 = AppConfigModel.fromJson(testJson);
      final entity = model1.toEntity();
      final model2 = AppConfigModel.fromEntity(entity);
      final json2 = model2.toJson();
      expect(json2['theme_mode'], testJson['theme_mode']);
      expect(json2['locale_code'], testJson['locale_code']);
      expect(json2['agent_id'], testJson['agent_id']);
      expect(json2['onboarding_completed'], testJson['onboarding_completed']);
      expect(json2['version'], testJson['version']);
    });

    test('uses defaults for missing optional fields', () {
      final minimalJson = <String, dynamic>{
        'theme_mode': 'dark',
        'locale_code': 'ku',
      };
      final model = AppConfigModel.fromJson(minimalJson);
      expect(model.agentId, 'aura');
      expect(model.onboardingCompleted, isFalse);
      expect(model.version, 1);
    });
  });
}
