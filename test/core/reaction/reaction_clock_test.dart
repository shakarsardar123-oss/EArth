import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/reaction/reaction.dart';

void main() {
  group('DefaultClock', () {
    test('returns a time close to now', () {
      final clock = const DefaultClock();
      final now = DateTime.now();
      final result = clock.now();

      // Within 2 seconds of wall clock
      expect(result.difference(now).inSeconds.abs(), lessThan(2));
    });

    test('millisecondsSinceEpoch is consistent', () {
      final clock = const DefaultClock();
      final ms = clock.millisecondsSinceEpoch();
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      expect((ms - nowMs).abs(), lessThan(2000));
    });
  });

  group('FrozenClock', () {
    test('returns fixed time', () {
      final fixed = DateTime(2026, 6, 15, 10, 30, 0);
      final clock = FrozenClock(fixed);

      expect(clock.now(), fixed);
    });

    test('advance moves time forward', () {
      final fixed = DateTime(2026, 1, 1, 0, 0, 0);
      final clock = FrozenClock(fixed);

      clock.advance(const Duration(hours: 3, minutes: 30));
      expect(clock.now(), DateTime(2026, 1, 1, 3, 30, 0));
    });

    test('setTo changes time to exact value', () {
      final clock = FrozenClock(DateTime(2025, 1, 1));
      final target = DateTime(2030, 12, 31, 23, 59, 59);

      clock.setTo(target);
      expect(clock.now(), target);
    });

    test('millisecondsSinceEpoch matches now', () {
      final fixed = DateTime(2026, 7, 4);
      final clock = FrozenClock(fixed);

      expect(clock.millisecondsSinceEpoch(), fixed.millisecondsSinceEpoch);
    });

    test('multiple advances accumulate', () {
      final clock = FrozenClock(DateTime(2026, 1, 1));

      clock.advance(const Duration(seconds: 10));
      clock.advance(const Duration(seconds: 20));
      clock.advance(const Duration(seconds: 30));

      expect(clock.now(), DateTime(2026, 1, 1, 0, 1, 0)); // 60s total
    });
  });
}
