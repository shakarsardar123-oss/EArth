/// task_dependency_test.dart
/// Structural tests for TaskDependency model.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/task_dependency.dart';

void main() {
  group('TaskDependency', () {
    test('constructs with dependencyId, sourceStepId, targetStepId', () {
      final d = TaskDependency(
        dependencyId: 'd1',
        sourceStepId: 'step1',
        targetStepId: 'step2',
      );
      expect(d.dependencyId, 'd1');
      expect(d.sourceStepId, 'step1');
      expect(d.targetStepId, 'step2');
    });

    test('source and target are distinct', () {
      final d = TaskDependency(
        dependencyId: 'd2',
        sourceStepId: 'a',
        targetStepId: 'b',
      );
      expect(d.sourceStepId, isNot(equals(d.targetStepId)));
    });
  });
}
