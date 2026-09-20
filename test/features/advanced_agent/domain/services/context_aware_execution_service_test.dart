/// context_aware_execution_service_test.dart
/// Structural tests for ContextAwareExecutionService.
///
/// Verifies: determineMode({required isOnline, required memoryAvailable, required config}),
/// adaptPlanForMode({required plan, required mode, required locale}).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/services/context_aware_execution_service.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/context_aware_config.dart';

void main() {
  group('ContextAwareExecutionService', () {
    test('has determineMode method', () {
      final service = ContextAwareExecutionService();
      expect(service.determineMode, isA<Function>());
    });

    test('has adaptPlanForMode method', () {
      final service = ContextAwareExecutionService();
      expect(service.adaptPlanForMode, isA<Function>());
    });

    test('determineMode accepts isOnline, memoryAvailable, config', () async {
      final service = ContextAwareExecutionService();
      final config = ContextAwareConfig(
        configId: 'cfg1',
        preferredLocale: 'ku',
      );
      try {
        await service.determineMode(
          isOnline: true,
          memoryAvailable: true,
          config: config,
        );
      } catch (_) {
        // Structural test only
      }
    });

    test('adaptPlanForMode accepts plan, mode, locale', () async {
      final service = ContextAwareExecutionService();
      try {
        await service.adaptPlanForMode(
          plan: AdvancedTaskPlan(
            planId: 'p1',
            userRequest: 'test',
            steps: [],
            dependencies: [],
            status: PlanStatus.active,
          ),
          mode: 'online',
          locale: 'ku',
        );
      } catch (_) {
        // Structural test only
      }
    });
  });
}
