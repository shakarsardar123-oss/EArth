import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/reaction/reaction.dart';

void main() {
  group('DefaultRandomSource', () {
    test('produces values in range', () {
      final random = DefaultRandomSource(42);
      for (var i = 0; i < 100; i++) {
        final d = random.nextDouble();
        expect(d, greaterThanOrEqualTo(0.0));
        expect(d, lessThan(1.0));
      }
    });

    test('nextInt produces values in range', () {
      final random = DefaultRandomSource(42);
      for (var i = 0; i < 100; i++) {
        final n = random.nextInt(10);
        expect(n, greaterThanOrEqualTo(0));
        expect(n, lessThan(10));
      }
    });

    test('same seed produces same sequence', () {
      final r1 = DefaultRandomSource(123);
      final r2 = DefaultRandomSource(123);

      for (var i = 0; i < 20; i++) {
        expect(r1.nextDouble(), r2.nextDouble());
      }
    });

    test('different seeds produce different sequences', () {
      final r1 = DefaultRandomSource(1);
      final r2 = DefaultRandomSource(2);

      var same = true;
      for (var i = 0; i < 20 && same; i++) {
        same = r1.nextDouble() == r2.nextDouble();
      }
      expect(same, isFalse);
    });
  });

  group('DeterministicRandomSource', () {
    test('returns fixed double sequence', () {
      final det = DeterministicRandomSource([0.1, 0.5, 0.9]);
      expect(det.nextDouble(), 0.1);
      expect(det.nextDouble(), 0.5);
      expect(det.nextDouble(), 0.9);
    });

    test('cycles when sequence exhausted', () {
      final det = DeterministicRandomSource([0.3, 0.7]);
      expect(det.nextDouble(), 0.3);
      expect(det.nextDouble(), 0.7);
      expect(det.nextDouble(), 0.3); // cycles
    });

    test('returns fixed int sequence', () {
      final det = DeterministicRandomSource([0.5], intValues: [3, 7, 1]);
      expect(det.nextInt(10), 3);
      expect(det.nextInt(10), 7);
      expect(det.nextInt(10), 1);
    });

    test('nextInt result is always < max', () {
      final det = DeterministicRandomSource([], intValues: [99, 50, 0]);
      expect(det.nextInt(10), 9);  // 99 % 10 = 9
      expect(det.nextInt(10), 0);  // 50 % 10 = 0
      expect(det.nextInt(10), 0);  // 0 % 10 = 0
    });

    test('empty double list returns 0.0', () {
      final det = DeterministicRandomSource([]);
      expect(det.nextDouble(), 0.0);
    });

    test('empty int list returns 0', () {
      final det = DeterministicRandomSource([]);
      expect(det.nextInt(5), 0);
    });

    test('reset restores initial state', () {
      final det = DeterministicRandomSource([0.2, 0.8]);
      expect(det.nextDouble(), 0.2);
      expect(det.nextDouble(), 0.8);

      det.reset();
      expect(det.nextDouble(), 0.2);
      expect(det.nextDouble(), 0.8);
    });
  });
}
