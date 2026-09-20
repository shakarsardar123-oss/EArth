/// pause_resume_state_test.dart
/// Structural tests for PauseResumeState model.
///
/// Verifies: enum values (running/paused/cancelled/pausing/resuming),
/// NO idle/completed values.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/pause_resume_state.dart';

void main() {
  group('PauseResumeState', () {
    test('has exactly 5 expected values', () {
      expect(PauseResumeState.values.length, 5);
    });

    test('contains running, paused, cancelled, pausing, resuming', () {
      expect(PauseResumeState.values, containsAll([
        PauseResumeState.running,
        PauseResumeState.paused,
        PauseResumeState.cancelled,
        PauseResumeState.pausing,
        PauseResumeState.resuming,
      ]));
    });

    test('does NOT contain idle or completed', () {
      final names = PauseResumeState.values.map((e) => e.name).toList();
      expect(names, isNot(contains('idle')));
      expect(names, isNot(contains('completed')));
    });
  });
}
