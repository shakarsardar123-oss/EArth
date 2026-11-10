import 'package:flutter_test/flutter_test.dart';
import '../../../lib/core/ai/key_detector.dart';

void main() {
  test('detects OpenRouter before OpenAI', () {
    final d = detectProviderFromKey('sk-or-v1-abc');
    expect(d.provider, DetectedProvider.openrouter);
    expect(d.baseUrl, 'https://openrouter.ai/api/v1');
  });

  test('detects Groq, Gemini, OpenAI, unknown', () {
    expect(detectProviderFromKey('gsk_xyz').provider, DetectedProvider.groq);
    expect(detectProviderFromKey('AIzaXYZ').provider, DetectedProvider.gemini);
    expect(detectProviderFromKey('sk-proj-1').provider, DetectedProvider.openai);
    expect(detectProviderFromKey('hello').provider, DetectedProvider.unknown);
  });

  test('skips non-chat models', () {
    final picked = pickChatModel([
      'whisper-large-v3',
      'canopylabs/orpheus-v1-english',
      'openai/gpt-oss-120b',
      'meta-llama/llama-prompt-guard-2-86m',
    ]);
    expect(picked, 'openai/gpt-oss-120b');
  });

  test('honours preferred order and returns null when nothing is chat', () {
    expect(pickChatModel(['a-gpt-4o', 'b-gpt-4o-mini'],
        preferred: ['gpt-4o-mini']), 'b-gpt-4o-mini');
    expect(pickChatModel(['whisper-1']), isNull);
  });
}
