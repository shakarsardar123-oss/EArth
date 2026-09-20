/// provider_registry.dart
/// AURA Assistant – R7-D: Provider Registry Service
///
/// UPDATED: gemini is now the first preset and default provider.
/// OpenAI is available as a secondary option.
/// Added supportedModels list, allowsCustomModel, icon property alias.
library;

import 'connection_type.dart';

/// A provider preset (template) for the provider picker UI.
class ProviderPreset {
  const ProviderPreset({
    required this.id,
    required this.displayName,
    required this.type,
    required this.defaultModel,
    required this.defaultBaseUrl,
    required this.iconEmoji,
    required this.description,
    this.isDefault = false,
    this.requiresApiKey = true,
    this.apiKeyHint = '',
    this.supportsVision = false,
    this.supportsStreaming = true,
    this.supportsTools = false,
    this.isBuiltIn = true,
    this.supportedModels = const [],
    this.allowsCustomModel = false,
  });

  final String id;
  final String displayName;

  /// Alias: the ConnectionType for this preset.
  final ConnectionType type;

  /// Alias for [type] used by the API key settings section.
  ConnectionType get connectionType => type;

  final String defaultModel;
  final String defaultBaseUrl;

  /// Alias for [iconEmoji] used by the API key settings section.
  String get icon => iconEmoji;

  final String iconEmoji;
  final String description;
  final bool isDefault;
  final bool requiresApiKey;
  final String apiKeyHint;
  final bool supportsVision;
  final bool supportsStreaming;
  final bool supportsTools;
  final bool isBuiltIn;

  /// List of model IDs this preset supports.
  final List<String> supportedModels;

  /// Whether the user can type a custom model name not in [supportedModels].
  final bool allowsCustomModel;
}

/// Registry of available AI provider presets.
///
/// Provides static metadata for each supported provider.
/// Used by the connection picker UI to display available options.
class ProviderRegistry {
  ProviderRegistry._();

  /// All built-in provider presets, ordered with gemini first.
  static const List<ProviderPreset> presets = [
    // ─── gemini (primary/default) ───────────────────────────
    ProviderPreset(
      id: 'gemini',
      displayName: 'Google gemini',
      type: ConnectionType.gemini,
      defaultModel: 'gemini-3.6-flash',
      defaultBaseUrl: '',
      iconEmoji: '✨',
      description:
          'Google gemini – fast, multilingual, supports vision & tools. Recommended for AURA.',
      isDefault: true,
      requiresApiKey: true,
      apiKeyHint: 'AIzaSy...',
      supportsVision: true,
      supportsStreaming: true,
      supportsTools: true,
      isBuiltIn: true,
      supportedModels: ['gemini-3.6-flash', 'gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-1.0-pro'],
      allowsCustomModel: true,
    ),

    // ─── OpenAI (secondary) ─────────────────────────────────
    ProviderPreset(
      id: 'openai',
      displayName: 'OpenAI',
      type: ConnectionType.openaiCompatible,
      defaultModel: 'gpt-4o-mini',
      defaultBaseUrl: '',
      iconEmoji: '🤖',
      description:
          'OpenAI GPT models – powerful but may not handle Kurdish RTL natively.',
      isDefault: false,
      requiresApiKey: true,
      apiKeyHint: 'sk-...',
      supportsVision: false,
      supportsStreaming: true,
      supportsTools: true,
      isBuiltIn: true,
      supportedModels: [
        'gpt-4o-mini',
        'gpt-4o',
      ],
      allowsCustomModel: true,
    ),

    // ─── Custom OpenAI-Compatible (tertiary) ────────────────
    ProviderPreset(
      id: 'custom_openai',
      displayName: 'Custom OpenAI-Compatible',
      type: ConnectionType.customOpenAI,
      defaultModel: '',
      defaultBaseUrl: '',
      iconEmoji: '🔧',
      description:
          'Any endpoint that implements the OpenAI chat/completions API.',
      isDefault: false,
      requiresApiKey: true,
      apiKeyHint: 'Your API key',
      supportsVision: false,
      supportsStreaming: true,
      supportsTools: false,
      isBuiltIn: true,
      supportedModels: [],
      allowsCustomModel: true,
    ),
  ];

  /// The default (primary) preset — gemini.
  static ProviderPreset get defaultPreset => presets.first;

  /// Lookup a preset by its id.
  static ProviderPreset? getPreset(String id) {
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  /// Alias for [getPresetByType] used by the API key settings section.
  static ProviderPreset? presetForType(ConnectionType type) =>
      getPresetByType(type);

  /// Get a preset by connection type.
  static ProviderPreset? getPresetByType(ConnectionType type) {
    for (final preset in presets) {
      if (preset.type == type) return preset;
    }
    return null;
  }

  /// Get all presets for a given connection type.
  static List<ProviderPreset> getPresetList(ConnectionType type) {
    return presets.where((p) => p.type == type).toList();
  }
}
