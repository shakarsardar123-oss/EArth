import '../entities/agent_config.dart';

/// Domain contract for managing agent configurations.
abstract class AgentConfigRepository {
  /// Returns all available agent configs.
  List<AgentConfig> getAllAgentConfigs();

  /// Returns the agent config with [id], or `null` if not found.
  AgentConfig? getAgentConfig(String id);

  /// Returns the default agent config (AURA).
  AgentConfig getDefaultAgentConfig();

  /// Persists a new or updated agent config.
  Future<void> saveAgentConfig(AgentConfig config);

  /// Deletes the agent config with [id].
  Future<void> deleteAgentConfig(String id);
}
