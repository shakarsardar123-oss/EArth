import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/reaction/reaction.dart';

void main() {
  group('ReactionHistory', () {
    late FrozenClock clock;
    late ReactionHistory history;

    setUp(() {
      clock = FrozenClock(DateTime(2026, 1, 1, 12, 0, 0));
      history = ReactionHistory(maxSize: 4, clock: clock);
    });

    test('starts empty', () {
      expect(history.isEmpty, isTrue);
      expect(history.length, 0);
    });

    test('record adds entry', () {
      history.record('r1');
      expect(history.length, 1);
      expect(history.entries.first.reactionId, 'r1');
    });

    test('ring buffer evicts oldest when full', () {
      history.record('r1');
      history.record('r2');
      history.record('r3');
      history.record('r4');
      expect(history.length, 4);
      expect(history.isFull, isTrue);

      history.record('r5');
      expect(history.length, 4);
      expect(history.entries.first.reactionId, 'r2');
      expect(history.entries.last.reactionId, 'r5');
    });

    test('isInCooldown returns true within cooldown window', () {
      history.record('r1');
      clock.advance(const Duration(seconds: 5));

      expect(
        history.isInCooldown('r1', const Duration(seconds: 10)),
        isTrue,
      );
    });

    test('isInCooldown returns false after cooldown expires', () {
      history.record('r1');
      clock.advance(const Duration(seconds: 31));

      expect(
        history.isInCooldown('r1', const Duration(seconds: 30)),
        isFalse,
      );
    });

    test('isInCooldown returns false for unknown reaction', () {
      expect(
        history.isInCooldown('unknown', const Duration(seconds: 10)),
        isFalse,
      );
    });

    test('timeSinceLast returns null for unknown reaction', () {
      expect(history.timeSinceLast('unknown'), isNull);
    });

    test('timeSinceLast returns duration for known reaction', () {
      history.record('r1');
      clock.advance(const Duration(seconds: 7));

      expect(history.timeSinceLast('r1'), const Duration(seconds: 7));
    });

    test('repeatCount returns correct count', () {
      history.record('r1');
      history.record('r2');
      history.record('r1'); // duplicate

      expect(history.repeatCount('r1'), 2);
      expect(history.repeatCount('r2'), 1);
      expect(history.repeatCount('r3'), 0);
    });

    test('recent returns last n entries', () {
      for (var i = 1; i <= 5; i++) {
        history.record('r$i');
      }

      final recent = history.recent(n: 3);
      expect(recent.length, 3);
      expect(recent[0].reactionId, 'r3');
      expect(recent[2].reactionId, 'r5');
    });

    test('recent returns all if fewer than n', () {
      history.record('r1');
      history.record('r2');

      final recent = history.recent(n: 10);
      expect(recent.length, 2);
    });

    test('clear empties the buffer', () {
      history.record('r1');
      history.record('r2');
      expect(history.length, 2);

      history.clear();
      expect(history.isEmpty, isTrue);
      expect(history.length, 0);
    });
  });

  group('ReactionHistoryEntry', () {
    test('equality', () {
      final time = DateTime(2026, 1, 1);
      final e1 = ReactionHistoryEntry(reactionId: 'r1', timestamp: time);
      final e2 = ReactionHistoryEntry(reactionId: 'r1', timestamp: time);
      final e3 = ReactionHistoryEntry(reactionId: 'r1', timestamp: time.add(const Duration(seconds: 1)));

      expect(e1 == e2, isTrue);
      expect(e1 == e3, isFalse);
    });
  });
}
