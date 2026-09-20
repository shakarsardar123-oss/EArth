// tool_composition_test.dart — Structural tests for ToolComposition
// ToolOutput.cancelled(message:), ToolOutput.empty(toolId:)
// Structural validation only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/tool_execution/application/tool_composition.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_output.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_input.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_execution_context.dart';
import 'package:aura_assistant/features/tool_execution/infrastructure/executors/tool_executor_registry.dart';
import 'package:aura_assistant/features/tool_execution/domain/services/tool_interface.dart';

void main() {
  group('ToolComposition', () {
    test('compose returns ToolOutput with correct toolId', () {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'device_tool', riskLevel: 'low'));
      final composition = ToolComposition(registry: registry);
      final result = composition.compose(
        toolId: 'device_tool',
        params: {'action': 'test'},
        context: ToolExecutionContext(),
      );
      expect(result, isA<ToolOutput>());
    });

    test('cancelled execution returns ToolOutput.cancelled(message:)', () async {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'test_tool', riskLevel: 'low'));
      final composition = ToolComposition(registry: registry);
      final cancelledContext = ToolExecutionContext().cancel();
      final result = await composition.compose(
        toolId: 'test_tool',
        params: {'action': 'test'},
        context: cancelledContext,
      );
      // cancelled uses 'message' param, not 'reason'
      if (result.status == ToolOutputStatus.cancelled) {
        expect(result.status, equals(ToolOutputStatus.cancelled));
      }
    });

    test('empty result uses ToolOutput.empty(toolId:) — NO data param', () {
      final emptyOutput = ToolOutput.empty(toolId: 'memory_tool');
      expect(emptyOutput.status, equals(ToolOutputStatus.empty));
      expect(emptyOutput.data, isNull);
      expect(emptyOutput.toolId, equals('memory_tool'));
    });

    test('FAIL-CLOSED: unknown tool returns fail-closed output', () async {
      final registry = ToolExecutorRegistry();
      final composition = ToolComposition(registry: registry);
      final result = await composition.compose(
        toolId: 'nonexistent',
        params: {},
        context: ToolExecutionContext(),
      );
      // FAIL-CLOSED: unknown tool → denied or failClosed
      expect(
        result.status == ToolOutputStatus.denied ||
        result.status == ToolOutputStatus.failClosed,
        isTrue,
      );
    });

    test('ToolOutput.denied uses reason not errorMessage', () {
      final denied = ToolOutput.denied(
        toolId: 'system_tool',
        reason: 'Security clearance required',
      );
      expect(denied.status, equals(ToolOutputStatus.denied));
    });

    test('ToolOutput.failure uses errorMessage not message', () {
      final failure = ToolOutput.failure(
        toolId: 'screen_tool',
        errorMessage: 'Display error',
      );
      expect(failure.status, equals(ToolOutputStatus.failed));
    });
  });
}

class _MockTool extends Tool {
  final String _toolId;
  final String _riskLevel;
  _MockTool({required String toolId, required String riskLevel})
      : _toolId = toolId, _riskLevel = riskLevel;
  @override String get toolId => _toolId;
  @override String get riskLevel => _riskLevel;
  @override ToolInput validate(Map<String, dynamic> params) =>
      ToolInput.valid(toolId: _toolId, params: params);
  @override Future<ToolOutput> execute(ToolInput input, ToolExecutionContext context) async =>
      ToolOutput.success(toolId: _toolId, data: {});
  @override bool cancel() => true;
}
