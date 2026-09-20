import '../../domain/entities/agent_config.dart';

/// Data-layer representation of an [AgentConfig], suitable for
/// JSON serialization and persistence.
class AgentConfigModel {
  const AgentConfigModel({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    this.modelId = 'default',
    this.temperature = 0.7,
    this.maxTokens = 2048,
    this.isDefault = false,
    this.isActive = true,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final String systemPrompt;
  final String modelId;
  final double temperature;
  final int maxTokens;
  final bool isDefault;
  final bool isActive;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Creates an [AgentConfigModel] from a JSON map.
  factory AgentConfigModel.fromJson(Map<String, dynamic> json) {
    return AgentConfigModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      systemPrompt: json['system_prompt'] as String,
      modelId: (json['model_id'] as String?) ?? 'default',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: (json['max_tokens'] as int?) ?? 2048,
      isDefault: (json['is_default'] as bool?) ?? false,
      isActive: (json['is_active'] as bool?) ?? true,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  /// Serializes this model to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'system_prompt': systemPrompt,
        'model_id': modelId,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'is_default': isDefault,
        'is_active': isActive,
        'avatar_url': avatarUrl,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  /// Converts this data model to a domain entity.
  AgentConfig toEntity() => AgentConfig(
        id: id,
        name: name,
        description: description,
        systemPrompt: systemPrompt,
        modelId: modelId,
        temperature: temperature,
        maxTokens: maxTokens,
        isDefault: isDefault,
        isActive: isActive,
        avatarUrl: avatarUrl,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// Creates a data model from a domain entity.
  factory AgentConfigModel.fromEntity(AgentConfig entity) => AgentConfigModel(
        id: entity.id,
        name: entity.name,
        description: entity.description,
        systemPrompt: entity.systemPrompt,
        modelId: entity.modelId,
        temperature: entity.temperature,
        maxTokens: entity.maxTokens,
        isDefault: entity.isDefault,
        isActive: entity.isActive,
        avatarUrl: entity.avatarUrl,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );
}
