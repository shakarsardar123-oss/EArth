/// live_mode_state_test.dart
/// AURA P0 – Unit tests for LiveModeState enum and LiveModeSession
///
/// Verifies: enum values, isActive, statusText (Kurdish Sorani),
/// LiveModeSession equality and generation guard.

import 'package:flutter_test/flutter_test.dart';
import 'package:texo/core/live_mode/live_mode_state.dart';

void main() {
  group('LiveModeState', () {
    test('has all 5 enum values', () {
      expect(LiveModeState.values.length, 5);
      expect(LiveModeState.values, containsAll([
        LiveModeState.idle,
        LiveModeState.listening,
        LiveModeState.processing,
        LiveModeState.speaking,
        LiveModeState.error,
      ]));
    });

    test('isActive is true only for listening, processing, speaking', () {
      expect(LiveModeState.idle.isActive, isFalse);
      expect(LiveModeState.listening.isActive, isTrue);
      expect(LiveModeState.processing.isActive, isTrue);
      expect(LiveModeState.speaking.isActive, isTrue);
      expect(LiveModeState.error.isActive, isFalse);
    });

    test('statusText returns Kurdish Sorani for all states', () {
      expect(LiveModeState.idle.statusText, 'ئامادەیە');
      expect(LiveModeState.listening.statusText, 'گوێگرتن...');
      expect(LiveModeState.processing.statusText, 'بیرکردنەوە...');
      expect(LiveModeState.speaking.statusText, 'قسەکردن...');
      expect(LiveModeState.error.statusText, 'هەڵە');
    });

    test('statusText is non-empty for every state', () {
      for (final state in LiveModeState.values) {
        expect(state.statusText, isNotEmpty);
      }
    });
  });

  group('LiveModeSession', () {
    test('stores sessionId and generation', () {
      final session = LiveModeSession(sessionId: 's1', generation: 3);
      expect(session.sessionId, 's1');
      expect(session.generation, 3);
    });

    test('isCurrent returns true when generations match', () {
      final session = LiveModeSession(sessionId: 's1', generation: 3);
      expect(session.isCurrent(3), isTrue);
    });

    test('isCurrent returns false when generations differ', () {
      final session = LiveModeSession(sessionId: 's1', generation: 3);
      expect(session.isCurrent(4), isFalse);
      expect(session.isCurrent(0), isFalse);
    });

    test('equality is based on sessionId and generation', () {
      final a = LiveModeSession(sessionId: 's1', generation: 1);
      final b = LiveModeSession(sessionId: 's1', generation: 1);
      final c = LiveModeSession(sessionId: 's1', generation: 2);
      final d = LiveModeSession(sessionId: 's2', generation: 1);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('hashCode is consistent with equality', () {
      final a = LiveModeSession(sessionId: 's1', generation: 1);
      final b = LiveModeSession(sessionId: 's1', generation: 1);
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
