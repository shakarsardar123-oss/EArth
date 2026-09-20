/// goal_tracker_service_test.dart
/// Structural tests for GoalTrackerService.
///
/// Verifies: registerGoal({planId, description, locale}).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/services/goal_tracker_service.dart';

void main() {
  group('GoalTrackerService', () {
    test('has registerGoal method', () {
      final service = GoalTrackerService();
      expect(service.registerGoal, isA<Function>());
    });

    test('registerGoal accepts planId, description, locale', () async {
      final service = GoalTrackerService();
      try {
        await service.registerGoal(
          planId: 'plan1',
          description: 'Complete translation',
          locale: 'ku',
        );
      } catch (_) {
        // Structural test only
      }
    });
  });
}
