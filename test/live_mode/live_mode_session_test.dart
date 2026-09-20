/// live_mode_session_test.dart
/// AURA P0 – Unit tests for LiveModeSession model
///
/// Verifies: session creation, generation token,
/// isCurrent detection, equality, immutability.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/live_mode/live_mode_state.dart';

void main() {
  group('LiveModeSession', () {
    test('construction stores sessionId and generation', () {
      final session = LiveModeSession(
        sessionId: 'sess-001',
        generation: 42,
      );
      expect(session.sessionId, 'sess-001');
      expect(session.generation, 42);
    });

    test('isCurrent returns true for matching generation', () {
      final session = LiveModeSession(
        sessionId: 'sess-001',
        generation: 5,
      );
      expect(session.isCurrent(5), isTrue);
    });

    test('isCurrent returns false for different generation', () {
      final session = LiveModeSession(
        sessionId: 'sess-001',
        generation: 5,
      );
      expect(session.isCurrent(99), isFalse);
    });

    test('equality works for identical sessions', () {
      final a = LiveModeSession(sessionId: 's1', generation: 1);
      final b = LiveModeSession(sessionId: 's1', generation: 1);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality for different sessionId', () {
      final a = LiveModeSession(sessionId: 's1', generation: 1);
      final b = LiveModeSession(sessionId: 's2', generation: 1);
      expect(a, isNot(equals(b)));
    });

    test('inequality for different generation', () {
      final a = LiveModeSession(sessionId: 's1', generation: 1);
      final b = LiveModeSession(sessionId: 's1', generation: 2);
      expect(a, isNot(equals(b)));
    });
  });
}
