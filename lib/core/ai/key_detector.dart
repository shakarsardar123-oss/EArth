/// Detects which AI provider an API key belongs to and picks a usable chat
/// model from a discovered list. Pure functions: no network, no storage,
/// and the key itself is never logged or returned.
library;

enum DetectedProvider { openrouter, groq, gemini, openai, unknown }

class DetectedKey {
  const DetectedKey(this.provider, this.baseUrl);
  final DetectedProvider provider;
  final String? baseUrl;
}

/// Checks the key prefix. `sk-or-` must be tested before `sk-`.
DetectedKey detectProviderFromKey(String key) {
  final k = key.trim();
  if (k.startsWith('sk-or-')) {
    return const DetectedKey(
        DetectedProvider.openrouter, 'https://openrouter.ai/api/v1');
  }
  if (k.startsWith('gsk_')) {
    return const DetectedKey(
        DetectedProvider.groq, 'https://api.groq.com/openai/v1');
  }
  if (k.startsWith('AIza')) {
    return const DetectedKey(DetectedProvider.gemini, null);
  }
  if (k.startsWith('sk-')) {
    return const DetectedKey(
        DetectedProvider.openai, 'https://api.openai.com/v1');
  }
  return const DetectedKey(DetectedProvider.unknown, null);
}

/// Markers of models that cannot hold a normal text conversation.
const List<String> _nonChatMarkers = [
  'whisper',
  'tts',
  'orpheus',
  'guard',
  'embed',
  'moderation',
  'image',
  'dall',
  'audio',
  'content-safety',
  'reward',
];

/// Returns the first chat-capable id, preferring ids that contain one of
/// [preferred] (in order). Returns null when no chat model exists.
String? pickChatModel(List<String> ids, {List<String> preferred = const []}) {
  final candidates = ids.where((id) {
    final lower = id.toLowerCase();
    for (final m in _nonChatMarkers) {
      if (lower.contains(m)) return false;
    }
    return true;
  }).toList();
  if (candidates.isEmpty) return null;

  for (final p in preferred) {
    final pl = p.toLowerCase();
    for (final c in candidates) {
      if (c.toLowerCase().contains(pl)) return c;
    }
  }
  return candidates.first;
}
