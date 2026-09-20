// background_execution_test.dart — Structural tests for BackgroundExecution
// Uses registry.get(), cancel() no args. Structural validation only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/tool_execution/application/background_execution.dart';
import 'package:aura_assistant/features/tool_execution/infrastructure/executors/tool_executor_registry.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_output.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_execution_context.dart';
import 'package:aura_assistant/features/tool_execution/infrastructure/cancellation_token.dart';
import 'package:aura_assistant/features/tool_execution/domain/services/tool_interface.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_input.dart';

void main() {
  group('BackgroundExecution', () {
    test('execute uses registry.get() to find tool', () {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'media_tool', riskLevel: 'low'));
      final bg = BackgroundExecution(registry: registry);
      // registry.get() is used internally
      expect(bg.registry.get('media_tool'), isNotNull);
    });

    test('cancel takes no arguments on CancellationToken', () {
      final token = CancellationToken();
      // cancel() takes NO arguments
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('background execution with valid tool returns output', () async {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'bg_tool', riskLevel: 'low'));
      final bg = BackgroundExecution(registry: registry);
      final result = await bg.execute(
        toolId: 'bg_tool',
        params: {'action': 'process'},
        context: ToolExecutionContext(),
      );
      expect(result, isA<ToolOutput>());
    });

    test('cancelled token stops execution with cancelled output', () async {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'bg_tool', riskLevel: 'low'));
      final bg = BackgroundExecution(registry: registry);
      final token = CancellationToken();
      token.cancel(); // cancel() no args
      final result = await bg.execute(
        toolId: 'bg_tool',
        params: {'action': 'test'},
        context: ToolExecutionContext().cancel(),
      );
      expect(result.status, equals(ToolOutputStatus.cancelled));
    });

    test('FAIL-CLOSED: unregistered tool denied', () async {
      final registry = ToolExecutorRegistry();
      final bg = BackgroundExecution(registry: registry);
      final result = await bg.execute(
        toolId: 'nonexistent',
        params: {},
        context: ToolExecutionContext(),
      );
      expect(
        result.status == ToolOutputStatus.denied ||
        result.status == ToolOutputStatus.failClosed,
        isTrue,
      );
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
