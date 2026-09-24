/// ai_connection_config.dart
/// AURA Assistant – R7-B: Unified AI Connection Config Model
///
/// UPDATED: Gemini is now the default provider.
/// - Default model: gemini-3.6-flash
/// - Default base URL: Gemini native API
/// - Default connection type: ConnectionType.gemini
///
/// Immutable model representing the user's AI connection configuration.
/// This is the single source of truth for connection settings
/// used by both chat and vision.
///
/// API key is NOT part of this model — it stays in secure storage
/// (provider-specific keys: aura_gemini_api_key, aura_openai_api_key).
library;

import 'connection_type.dart';

/// Default model for chat completions — Gemini primary.
const kDefaultChatModel = 'gemini-3.6-flash';

/// Default model for vision (Gemini supports image input natively).
///
/// NOTE: Vision intentionally stays on gemini-1.5-flash. The chat default
/// migration to gemini-3.6-flash does NOT touch the vision pipeline.
const kDefaultVisionModel = 'gemini-1.5-flash';

/// Default Gemini native base URL.
const kDefaultBaseUrl = '';

/// Default OpenAI base URL (secondary provider).
const kOpenAIDefaultBaseUrl = 'https://api.openai.com/v1';

/// Unified AI connection configuration model.
///
/// Immutable value object. Create new instances via copyWith
/// or the named constructors.
class AIConnectionConfig {
  const AIConnectionConfig({
    required this.connectionType,
    required this.baseUrl,
    required this.model,
  });

  /// Creates a config with Gemini as default (primary provider).
  const AIConnectionConfig.defaults()
      : connectionType = ConnectionType.gemini,
        baseUrl = kDefaultBaseUrl,
        model = kDefaultChatModel;

  /// Creates a config with OpenAI defaults.
  const AIConnectionConfig.openaiDefaults()
      : connectionType = ConnectionType.openaiCompatible,
        baseUrl = kOpenAIDefaultBaseUrl,
        model = 'gpt-4o-mini';

  /// The type of AI connection.
  final ConnectionType connectionType;

  /// Base URL for the API endpoint (HTTPS only, validated by EndpointValidator).
  final String baseUrl;

  /// Model name to use for requests.
  final String model;

  /// Whether this config uses any OpenAI-compatible connection type.
  bool get isOpenAICompatible =>
      connectionType == ConnectionType.openaiCompatible ||
      connectionType == ConnectionType.customOpenAI;

  /// Whether this config uses the Gemini connection type.
  bool get isGemini => connectionType == ConnectionType.gemini;

  /// Whether the model field is non-empty and non-whitespace.
  bool get hasValidModel => model.trim().isNotEmpty;

  /// Create a copy with optional field overrides.
  AIConnectionConfig copyWith({
    ConnectionType? connectionType,
    String? baseUrl,
    String? model,
  }) {
    return AIConnectionConfig(
      connectionType: connectionType ?? this.connectionType,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AIConnectionConfig &&
        other.connectionType == connectionType &&
        other.baseUrl == baseUrl &&
        other.model == model;
  }

  @override
  int get hashCode => Object.hash(connectionType, baseUrl, model);

  @override
  String toString() =>
      'AIConnectionConfig(type: $connectionType, baseUrl: $baseUrl, model: $model)';
}
