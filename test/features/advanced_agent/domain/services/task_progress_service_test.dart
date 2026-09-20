/// task_progress_service_test.dart
/// Structural tests for TaskProgressService.
///
/// Verifies: buildProgress, getProgress, recordError, reset, watchProgress.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/services/task_progress_service.dart';

void main() {
  group('TaskProgressService', () {
    test('has buildProgress method', () {
      final service = TaskProgressService();
      expect(service.buildProgress, isA<Function>());
    });

    test('has getProgress method', () {
      final service = TaskProgressService();
      expect(service.getProgress, isA<Function>());
    });

    test('has recordError method', () {
      final service = TaskProgressService();
      expect(service.recordError, isA<Function>());
    });

    test('has reset method', () {
      final service = TaskProgressService();
      expect(service.reset, isA<Function>());
    });

    test('has watchProgress method', () {
      final service = TaskProgressService();
      expect(service.watchProgress, isA<Function>());
    });
  });
}
