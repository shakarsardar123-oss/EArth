/// model_discovery.dart
/// AURA Assistant – Phase 1: Non-breaking Model Discovery + Capability Filtering
///
/// This file introduces model discovery WITHOUT touching the existing
/// [AIProvider] interface. Discovery is expressed as a SEPARATE optional
/// capability interface [ModelDiscovery]. Providers that support live
/// discovery (Gemini, OpenAI) implement it in addition to [AIProvider];
/// providers/custom implementations that do NOT implement it keep working
/// unchanged. Callers use `if (provider is ModelDiscovery)` to opt in.
///
/// It also provides:
/// - [AIModelInfo]: a normalized, provider-independent model descriptor.
/// - [ModelCapabilityFilter]: filters a discovered list down to models
///   actually usable for normal text/chat generation.
/// - [ModelSelector]: deterministic preference-order selection.
library;

/// Coarse capability category inferred from a provider's model metadata.
enum AIModelCategory {
  /// Normal text / chat / conversational generation model.
  chat,

  /// Text-embedding model (NOT usable for chat).
  embedding,

  /// Image generation model (NOT usable for chat).
  image,

  /// Audio / speech / transcription model (NOT usable for chat).
  audio,

  /// Moderation-only model (NOT usable for chat).
  moderation,

  /// Anything we cannot confidently classify.
  other,
}

/// Provider-independent descriptor for a single discovered model.
///
/// [id] is the normalized id AURA uses internally and persists
/// (e.g. `gemini-3.6-flash`, `gpt-4o-mini`) — already stripped of any
/// provider-specific prefix such as Gemini's `models/`.
class AIModelInfo {
  const AIModelInfo({
    required this.id,
    required this.rawId,
    this.category = AIModelCategory.other,
    this.supportsChat = false,
    this.supportsTools = false,
    this.displayName,
  });

  /// Normalized model id (what we store & send in requests).
  final String id;

  /// The original id/name as returned by the provider API.
  final String rawId;

  /// Inferred capability category.
  final AIModelCategory category;

  /// Whether this model can perform normal text/chat generation.
  final bool supportsChat;

  /// Whether this model is known to support tool / function calling.
  final bool supportsTools;

  /// Optional human-friendly name.
  final String? displayName;

  @override
  String toString() =>
      'AIModelInfo($id, category: $category, chat: $supportsChat, tools: $supportsTools)';
}

/// Optional capability: live model discovery via the provider's API.
///
/// Kept SEPARATE from [AIProvider] on purpose so that adding discovery
/// does not force every existing/custom [AIProvider] implementation to
/// change. Only providers that actually support it implement this.
abstract interface class ModelDiscovery {
  /// Discovers the models currently available for this provider/key.
  ///
  /// Implementations should return a provider-independent list of
  /// [AIModelInfo]. On failure they MUST throw an
  /// `AIProviderException` (structured) rather than a raw
  /// `FormatException`/`SocketException`.
  Future<List<AIModelInfo>> listModels();
}

/// Filters a discovered model list down to models usable for chat.
class ModelCapabilityFilter {
  ModelCapabilityFilter._();

  /// Substrings that strongly indicate a NON-chat model, used as a
  /// defensive secondary guard on top of category classification.
  static const List<String> _nonChatMarkers = [
    'embedding',
    'embed',
    'imagen',
    'image-generation',
    'dall-e',
    'dalle',
    'whisper',
    'tts',
    'text-to-speech',
    'audio',
    'moderation',
    'aqa',
    'vision-only',
  ];

  /// Returns only models appropriate for normal chat/text generation.
  ///
  /// A model is kept only if it is [AIModelCategory.chat] AND
  /// [AIModelInfo.supportsChat] is true AND its id does not contain a
  /// known non-chat marker. This deliberately excludes embedding,
  /// image, audio-only and moderation models.
  static List<AIModelInfo> chatModels(List<AIModelInfo> models) {
    return models.where((m) {
      if (!m.supportsChat) return false;
      if (m.category != AIModelCategory.chat) return false;
      final lower = m.id.toLowerCase();
      for (final marker in _nonChatMarkers) {
        if (lower.contains(marker)) return false;
      }
      return true;
    }).toList();
  }
}

/// Deterministic model selection using a provider preference order.
class ModelSelector {
  ModelSelector._();

  /// Deterministic preference order for Gemini chat models.
  ///
  /// Earlier entries win. Entries are matched as case-insensitive
  /// substrings against the discovered model id, so partial families
  /// (e.g. `flash`) act as broad fallbacks after exact ids.
  static const List<String> geminiPreferenceOrder = [
    'gemini-3.6-flash',
    'gemini-3.6',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'gemini-1.0-pro',
    'flash',
    'pro',
    'gemini',
  ];

  /// Deterministic preference order for OpenAI chat models.
  static const List<String> openAIPreferenceOrder = [
    'gpt-4o-mini',
    'gpt-4o',
    'gpt-4.1-mini',
    'gpt-4.1',
    'gpt-4-turbo',
    'gpt-4',
    'gpt-3.5-turbo',
    'o4-mini',
    'o3-mini',
    'gpt',
  ];

  /// Selects the most preferred chat-capable model from [models].
  ///
  /// Algorithm (fully deterministic):
  /// 1. Filter to chat-capable models via [ModelCapabilityFilter].
  /// 2. Drop any model whose id is in [exclude] (case-insensitive).
  /// 3. For each pattern in [preferenceOrder] (in order), return the
  ///    first remaining model whose id contains that pattern. When
  ///    several models match the SAME pattern, the alphabetically
  ///    smallest id is chosen so the result is stable.
  /// 4. If no preference pattern matches, return the alphabetically
  ///    smallest remaining chat model.
  /// 5. If nothing remains, return null.
  static AIModelInfo? select(
    List<AIModelInfo> models, {
    required List<String> preferenceOrder,
    Set<String> exclude = const {},
  }) {
    final excludeLower = exclude.map((e) => e.toLowerCase()).toSet();
    final candidates = ModelCapabilityFilter.chatModels(models)
        .where((m) => !excludeLower.contains(m.id.toLowerCase()))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    if (candidates.isEmpty) return null;

    for (final pattern in preferenceOrder) {
      final p = pattern.toLowerCase();
      for (final m in candidates) {
        if (m.id.toLowerCase().contains(p)) return m;
      }
    }

    return candidates.first;
  }
}
