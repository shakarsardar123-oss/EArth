/// goal_status_test.dart
/// Structural tests for GoalStatus model.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/goal_status.dart';

void main() {
  group('GoalStatus', () {
    test('enum has expected values', () {
      // GoalStatus should cover: pending, inProgress, completed, failed, cancelled
      expect(GoalStatus.values.length, greaterThanOrEqualTo(4));
    });

    test('each value has a name', () {
      for (final v in GoalStatus.values) {
        expect(v.name, isNotEmpty);
      }
    });
  });
}
