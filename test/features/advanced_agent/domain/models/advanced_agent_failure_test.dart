/// advanced_agent_failure_test.dart
/// Structural tests for AdvancedAgentFailure model.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/advanced_agent_failure.dart';

void main() {
  group('AdvancedAgentFailure', () {
    test('constructs with failureId, type, message', () {
      final f = AdvancedAgentFailure(
        failureId: 'f1',
        type: 'tool_error',
        message: 'Tool execution failed',
      );
      expect(f.failureId, 'f1');
      expect(f.type, 'tool_error');
      expect(f.message, 'Tool execution failed');
    });

    test('optional fields: stepId, toolId, recoverable', () {
      final f = AdvancedAgentFailure(
        failureId: 'f2',
        type: 'network',
        message: 'Connection lost',
        stepId: 's1',
        toolId: 't1',
        recoverable: true,
      );
      expect(f.stepId, 's1');
      expect(f.toolId, 't1');
      expect(f.recoverable, isTrue);
    });
  });
}
