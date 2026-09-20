import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/audio/audio_signal_math.dart';

void main() {
  group('rmsFromPcm16', () {
    test('silence is 0', () {
      expect(rmsFromPcm16(Int16List(256)), 0.0);
    });

    test('empty is 0', () {
      expect(rmsFromPcm16(Int16List(0)), 0.0);
    });

    test('full-scale square wave approaches 1.0', () {
      final s = Int16List.fromList(List.generate(
          256, (i) => i.isEven ? 32767 : -32768));
      final rms = rmsFromPcm16(s);
      expect(rms, greaterThan(0.99));
      expect(rms, lessThanOrEqualTo(1.0));
    });

    test('half-scale is ~0.5', () {
      final s = Int16List.fromList(List.generate(
          256, (i) => i.isEven ? 16384 : -16384));
      expect(rmsFromPcm16(s), closeTo(0.5, 0.01));
    });
  });

  group('peakFromPcm16', () {
    test('captures max abs sample', () {
      final s = Int16List.fromList([0, 100, -16384, 5]);
      expect(peakFromPcm16(s), closeTo(0.5, 0.01));
    });
  });

  group('zeroCrossingRate', () {
    test('alternating sign is ~1.0', () {
      final s = Int16List.fromList(List.generate(
          100, (i) => i.isEven ? 1000 : -1000));
      expect(zeroCrossingRate(s), closeTo(1.0, 0.02));
    });

    test('constant sign is 0', () {
      final s = Int16List.fromList(List.filled(100, 1000));
      expect(zeroCrossingRate(s), 0.0);
    });
  });

  group('RmsNormalizer', () {
    test('clamps below floor to 0 and above ceiling to 1', () {
      final n = RmsNormalizer(floor: 0.0, ceiling: 10.0);
      expect(n.normalize(-5), 0.0);
      expect(n.normalize(0), 0.0);
      expect(n.normalize(5), 0.5);
      expect(n.normalize(10), 1.0);
      expect(n.normalize(100), 1.0);
    });

    test('handles NaN / infinity safely', () {
      final n = RmsNormalizer.linearRms();
      expect(n.normalize(double.nan), 0.0);
      expect(n.normalize(double.infinity), 0.0);
    });

    test('stt factory maps the platform range', () {
      final n = RmsNormalizer.sttSoundLevel();
      expect(n.normalize(-2.0), 0.0);
      expect(n.normalize(10.0), 1.0);
    });
  });

  group('LevelSmoother', () {
    test('rises fast, decays slow, stays in 0..1', () {
      final s = LevelSmoother(attack: 0.5, release: 0.1);
      final up = s.add(1.0);
      expect(up, closeTo(0.5, 1e-9));
      // Falling uses the slower release coefficient.
      final down = s.add(0.0);
      expect(down, closeTo(0.45, 1e-9));
      expect(down, greaterThan(0.0));
    });

    test('snaps tiny values to 0', () {
      final s = LevelSmoother(initial: 0.00005);
      expect(s.add(0.0), 0.0);
    });

    test('never exceeds 1 for clipped input', () {
      final s = LevelSmoother(attack: 1.0);
      expect(s.add(5.0), 1.0);
    });
  });
}
