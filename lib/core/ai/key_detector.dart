library;

enum DetectedProvider { openrouter, groq, gemini, openai, unknown }

class DetectedKey {
  const DetectedKey(this.provider, this.baseUrl);
  final DetectedProvider provider;
  final String? baseUrl;
}

DetectedKey detectProviderFromKey(String key) {
  final k = key.trim();
  if (k.startsWith('sk-or-')) {
    return const DetectedKey(DetectedProvider.openrouter, 'https://openrouter.ai/api/v1');
  }
  if (k.startsWith('gsk_')) {
    return const DetectedKey(DetectedProvider.groq, 'https://api.groq.com/openai/v1');
  }
  if (k.startsWith('AIza')) {
    return const DetectedKey(DetectedProvider.gemini, null);
  }
  if (k.startsWith('sk-')) {
    return const DetectedKey(DetectedProvider.openai, 'https://api.openai.com/v1');
  }
  return const DetectedKey(DetectedProvider.unknown, null);
}

const List<String> _nonChatMarkers = [
  'whisper', 'tts', 'orpheus', 'guard', 'embed', 'moderation',
  'image', 'dall', 'audio', 'content-safety', 'reward',
];

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
