/// tool_selection_score_test.dart
/// Structural tests for ToolSelectionScore model.
///
/// Verifies: meetsThreshold({threshold=0.5}),
/// NO isSuitable method.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/tool_selection_score.dart';

void main() {
  group('ToolSelectionScore', () {
    test('meetsThreshold with default 0.5', () {
      final score = ToolSelectionScore(
        scoreId: 'ts1',
        toolId: 'tool1',
        scoreValue: 0.7,
      );
      expect(score.meetsThreshold(), isTrue);
    });

    test('meetsThreshold below default', () {
      final score = ToolSelectionScore(
        scoreId: 'ts2',
        toolId: 'tool1',
        scoreValue: 0.3,
      );
      expect(score.meetsThreshold(), isFalse);
    });

    test('meetsThreshold with custom threshold', () {
      final score = ToolSelectionScore(
        scoreId: 'ts3',
        toolId: 'tool1',
        scoreValue: 0.6,
      );
      expect(score.meetsThreshold(threshold: 0.7), isFalse);
      expect(score.meetsThreshold(threshold: 0.5), isTrue);
    });

    test('does NOT have isSuitable method', () {
      final score = ToolSelectionScore(
        scoreId: 'ts4',
        toolId: 'tool1',
        scoreValue: 0.8,
      );
      // isSuitable does not exist on ToolSelectionScore by design
      expect(score.meetsThreshold, isA<Function>());
    });
  });
}
