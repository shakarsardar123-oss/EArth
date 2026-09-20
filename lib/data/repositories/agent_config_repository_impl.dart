import '../../domain/entities/agent_config.dart';
import '../../domain/repositories/agent_config_repository.dart';
import '../models/agent_config_model.dart';

/// Concrete implementation of [AgentConfigRepository].
///
/// Phase 1 loads agent configs from hardcoded defaults. Future phases
/// will persist them via [LocalStorageDataSource] or a remote API.
class AgentConfigRepositoryImpl implements AgentConfigRepository {
  AgentConfigRepositoryImpl();

  /// In-memory cache of default agent configs.
  final Map<String, AgentConfigModel> _agents = {};

  /// Initializes default agents.
  void _ensureDefaults() {
    if (_agents.containsKey('aura')) return;
    _agents['aura'] = AgentConfigModel(
      id: 'aura',
      name: 'AURA',
      description: 'یاریدەدەری زیرەکی کەسی — کوردی سۆرانی',
      systemPrompt: AgentConfig.defaultConfig.systemPrompt,
      modelId: 'default',
      temperature: 0.7,
      maxTokens: 2048,
      isDefault: true,
      isActive: true,
    );
  }

  @override
  List<AgentConfig> getAllAgentConfigs() {
    _ensureDefaults();
    return _agents.values.map((m) => m.toEntity()).toList();
  }

  @override
  AgentConfig? getAgentConfig(String id) {
    _ensureDefaults();
    final model = _agents[id];
    return model?.toEntity();
  }

  @override
  AgentConfig getDefaultAgentConfig() {
    _ensureDefaults();
    return _agents['aura']!.toEntity();
  }

  @override
  Future<void> saveAgentConfig(AgentConfig config) async {
    _agents[config.id] = AgentConfigModel.fromEntity(config);
    // Phase 2+: persist to local storage or remote API.
  }

  @override
  Future<void> deleteAgentConfig(String id) async {
    _agents.remove(id);
    // Phase 2+: remove from persistent storage.
  }
}
