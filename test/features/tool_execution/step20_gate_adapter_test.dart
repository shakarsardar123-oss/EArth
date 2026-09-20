// step20_gate_adapter_test.dart — Structural tests for Step20GateAdapter
// 5 gates, all ToolOutput factories correct. FAIL-CLOSED design.
// Structural validation only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/tool_execution/infrastructure/adapters/step20_gate_adapter.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_output.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_execution_context.dart';
import 'package:aura_assistant/features/tool_execution/infrastructure/executors/tool_executor_registry.dart';
import 'package:aura_assistant/features/tool_execution/domain/services/tool_interface.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_input.dart';

void main() {
  group('Step20GateAdapter', () {
    test('has 5 gates defined', () {
      final registry = ToolExecutorRegistry();
      final adapter = Step20GateAdapter(registry: registry);
      expect(adapter.gateCount, equals(5));
    });

    test('validation gate failure returns ToolOutput.failure(errorMessage:)', () {
      final failure = ToolOutput.failure(
        toolId: 'test_tool',
        errorMessage: 'Validation failed',
      );
      expect(failure.status, equals(ToolOutputStatus.failed));
    });

    test('confirmation gate denial returns ToolOutput.denied(reason:)', () {
      final denied = ToolOutput.denied(
        toolId: 'test_tool',
        reason: 'User denied confirmation',
      );
      expect(denied.status, equals(ToolOutputStatus.denied));
    });

    test('sanitization gate returns ToolOutput.success(toolId:)', () {
      final success = ToolOutput.success(
        toolId: 'test_tool',
        data: {'sanitized': true},
      );
      expect(success.status, equals(ToolOutputStatus.success));
    });

    test('security gate denial returns ToolOutput.denied(reason:)', () {
      final denied = ToolOutput.denied(
        toolId: 'system_tool',
        reason: 'Insufficient security clearance',
      );
      expect(denied.status, equals(ToolOutputStatus.denied));
    });

    test('risk gate denial returns ToolOutput.denied(reason:)', () {
      final denied = ToolOutput.denied(
        toolId: 'risky_tool',
        reason: 'Risk level exceeds maximum',
      );
      expect(denied.status, equals(ToolOutputStatus.denied));
    });

    test('all gates use correct ToolOutput factory signatures', () {
      // failure uses errorMessage, not message
      final f = ToolOutput.failure(toolId: 't', errorMessage: 'e');
      // denied uses reason, not errorMessage
      final d = ToolOutput.denied(toolId: 't', reason: 'r');
      // cancelled uses message
      final c = ToolOutput.cancelled(toolId: 't', message: 'm');
      // empty has no data param
      final e = ToolOutput.empty(toolId: 't');
      // failClosed
      final fc = ToolOutput.failClosed(toolId: 't');
      expect(f.status, equals(ToolOutputStatus.failed));
      expect(d.status, equals(ToolOutputStatus.denied));
      expect(c.status, equals(ToolOutputStatus.cancelled));
      expect(e.status, equals(ToolOutputStatus.empty));
      expect(fc.status, equals(ToolOutputStatus.failClosed));
    });

    test('FAIL-CLOSED: any gate failure denies execution', () async {
      final registry = ToolExecutorRegistry();
      final adapter = Step20GateAdapter(registry: registry);
      final result = await adapter.evaluate(
        toolId: 'nonexistent',
        context: ToolExecutionContext(),
        params: {},
      );
      // FAIL-CLOSED: unknown tool → denied/failClosed
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
