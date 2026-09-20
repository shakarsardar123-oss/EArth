import '../../domain/entities/app_config.dart';

/// Data-layer representation of [AppConfig], suitable for
/// JSON serialization and persistence.
class AppConfigModel {
  const AppConfigModel({
    required this.themeMode,
    required this.localeCode,
    this.agentId = 'aura',
    this.onboardingCompleted = false,
    this.version = 1,
  });

  final String themeMode;
  final String localeCode;
  final String agentId;
  final bool onboardingCompleted;
  final int version;

  factory AppConfigModel.fromJson(Map<String, dynamic> json) {
    return AppConfigModel(
      themeMode: (json['theme_mode'] as String?) ?? 'dark',
      localeCode: (json['locale_code'] as String?) ?? 'ku',
      agentId: (json['agent_id'] as String?) ?? 'aura',
      onboardingCompleted: (json['onboarding_completed'] as bool?) ?? false,
      version: (json['version'] as int?) ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'theme_mode': themeMode,
        'locale_code': localeCode,
        'agent_id': agentId,
        'onboarding_completed': onboardingCompleted,
        'version': version,
      };

  AppConfig toEntity() => AppConfig(
        themeMode: themeMode,
        localeCode: localeCode,
        agentId: agentId,
        onboardingCompleted: onboardingCompleted,
        version: version,
      );

  factory AppConfigModel.fromEntity(AppConfig entity) => AppConfigModel(
        themeMode: entity.themeMode,
        localeCode: entity.localeCode,
        agentId: entity.agentId,
        onboardingCompleted: entity.onboardingCompleted,
        version: entity.version,
      );
}
