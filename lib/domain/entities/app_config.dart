/// Domain entity representing application-wide configuration.
///
/// Tracks theme, locale, active agent, and onboarding state.
class AppConfig {
  const AppConfig({
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

  AppConfig copyWith({
    String? themeMode,
    String? localeCode,
    String? agentId,
    bool? onboardingCompleted,
    int? version,
  }) {
    return AppConfig(
      themeMode: themeMode ?? this.themeMode,
      localeCode: localeCode ?? this.localeCode,
      agentId: agentId ?? this.agentId,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      version: version ?? this.version,
    );
  }
}
