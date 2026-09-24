/// Centralized application constants for AURA.
/// 
/// All application-wide constant values should be defined here
/// and referenced via [AppConstants] throughout the codebase.
class AppConstants {
  AppConstants._();

  // Application identity
  static const String appName = 'TEXO';
  static const String defaultAgentName = 'TEXO';
  static const String appVersion = '0.1.0';
  static const int appBuildNumber = 1;

  // Localization
  static const String defaultLocaleCode = 'ku';
  static const String defaultCountryCode = 'IQ';
  static const String fallbackLocaleCode = 'en';

  // Database
  static const String databaseName = 'aura_database.db';
  static const int databaseVersion = 1;

  // Storage keys
  static const String secureStoragePrefix = 'aura_secure_';
  static const String prefsStoragePrefix = 'aura_prefs_';
  static const String appConfigKey = 'aura_prefs_app_config';
  static const String agentConfigKey = 'aura_prefs_agent_config';
  static const String themeKey = 'aura_prefs_theme';
  static const String localeKey = 'aura_prefs_locale';
  static const String onboardingKey = 'aura_prefs_onboarding';
  static const String activeAgentKey = 'aura_prefs_active_agent';

  // Floating AURA overlay storage keys
  static const String floatingAuraPositionXKey =
      'aura_prefs_floating_aura_position_x';
  static const String floatingAuraPositionYKey =
      'aura_prefs_floating_aura_position_y';
  static const String floatingAuraIsExpandedKey =
      'aura_prefs_floating_aura_is_expanded';
  static const String floatingAuraIsVisibleKey =
      'aura_prefs_floating_aura_is_visible';
}
