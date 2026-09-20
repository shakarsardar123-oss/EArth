import '../entities/app_config.dart';

/// Domain contract for persisting and reading app configuration.
abstract class AppConfigRepository {
  /// Returns the current [AppConfig].
  AppConfig getAppConfig();

  /// Persists the given [config].
  Future<void> saveAppConfig(AppConfig config);

  /// Updates only the active agent id.
  Future<void> setActiveAgentId(String agentId);

  /// Returns the active agent id.
  String getActiveAgentId();
}
