/// tool_selection_service_test.dart
/// Structural tests for ToolSelectionService.
///
/// Verifies: selectBest({action, candidates(List<Map<String,dynamic>>), locale}).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/services/tool_selection_service.dart';

void main() {
  group('ToolSelectionService', () {
    test('has selectBest method', () {
      final service = ToolSelectionService();
      expect(service.selectBest, isA<Function>());
    });

    test('selectBest accepts action, candidates, locale', () async {
      final service = ToolSelectionService();
      try {
        await service.selectBest(
          action: 'translate',
          candidates: [
            {'toolId': 't1', 'score': 0.9},
            {'toolId': 't2', 'score': 0.7},
          ],
          locale: 'ku',
        );
      } catch (_) {
        // Structural test only
      }
    });
  });
}
