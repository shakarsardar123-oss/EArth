/// replanner_service_test.dart
/// Structural tests for ReplannerService.
///
/// Verifies: replanOnFailure({currentPlan, failure, locale}) → Future<AdvancedTaskPlan?>,
/// maxReplanAttempts.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/services/replanner_service.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/advanced_task_plan.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/advanced_agent_failure.dart';

void main() {
  group('ReplannerService', () {
    test('has replanOnFailure method', () {
      final service = ReplannerService();
      expect(service.replanOnFailure, isA<Function>());
    });

    test('has maxReplanAttempts property', () {
      final service = ReplannerService();
      expect(service.maxReplanAttempts, isA<int>());
    });

    test('replanOnFailure accepts currentPlan, failure, locale', () async {
      final service = ReplannerService();
      try {
        await service.replanOnFailure(
          currentPlan: AdvancedTaskPlan(
            planId: 'p1',
            userRequest: 'test',
            steps: [],
            dependencies: [],
            status: PlanStatus.active,
          ),
          failure: AdvancedAgentFailure(
            failureId: 'f1',
            type: 'tool_error',
            message: 'failed',
          ),
          locale: 'ku',
        );
      } catch (_) {
        // Structural test only
      }
    });
  });
}
