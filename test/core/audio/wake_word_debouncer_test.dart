import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/audio/wake_word_debouncer.dart';

void main() {
  group('WakeWordDebouncer', () {
    test('accepts the first detection', () {
      final d = WakeWordDebouncer(cooldown: const Duration(seconds: 2));
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      expect(d.shouldAccept(now: t0), isTrue);
    });

    test('suppresses duplicate within cooldown (one utterance = one wake)', () {
      final d = WakeWordDebouncer(cooldown: const Duration(seconds: 2));
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      expect(d.shouldAccept(now: t0), isTrue);
      expect(d.shouldAccept(now: t0.add(const Duration(milliseconds: 200))),
          isFalse);
      expect(d.shouldAccept(now: t0.add(const Duration(milliseconds: 1999))),
          isFalse);
    });

    test('accepts again after cooldown elapses', () {
      final d = WakeWordDebouncer(cooldown: const Duration(seconds: 2));
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      expect(d.shouldAccept(now: t0), isTrue);
      expect(d.shouldAccept(now: t0.add(const Duration(seconds: 3))), isTrue);
    });

    test('rejects detections below the confidence threshold', () {
      final d = WakeWordDebouncer(minConfidence: 0.6);
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      expect(d.shouldAccept(now: t0, confidence: 0.4), isFalse);
      expect(d.shouldAccept(now: t0, confidence: 0.9), isTrue);
    });

    test('reset clears the cooldown', () {
      final d = WakeWordDebouncer(cooldown: const Duration(seconds: 2));
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      expect(d.shouldAccept(now: t0), isTrue);
      d.reset();
      expect(d.shouldAccept(now: t0.add(const Duration(milliseconds: 10))),
          isTrue);
    });
  });
}
