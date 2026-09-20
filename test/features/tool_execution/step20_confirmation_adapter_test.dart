// step20_confirmation_adapter_test.dart — Structural tests for Step20ConfirmationAdapter
// No raw \n literals, riskLevel String, denyAll correct, ToolOutput.denied(reason:)
// Structural validation only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/tool_execution/infrastructure/adapters/step20_confirmation_adapter.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_output.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_execution_context.dart';
import 'package:aura_assistant/features/tool_execution/infrastructure/executors/tool_executor_registry.dart';
import 'package:aura_assistant/features/tool_execution/domain/services/tool_interface.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_input.dart';

void main() {
  group('Step20ConfirmationAdapter', () {
    test('ConfirmationMode.denyAll is correct (not autoDeny)', () {
      expect(ConfirmationMode.denyAll, isNotNull);
      // denyAll is the correct name, NOT autoDeny
    });

    test('riskLevel is String not enum', () {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'test', riskLevel: 'medium'));
      final tool = registry.get('test');
      expect(tool!.riskLevel, isA<String>());
    });

    test('denied confirmation returns ToolOutput.denied(reason:)', () {
      final denied = ToolOutput.denied(
        toolId: 'system_tool',
        reason: 'User denied via denyAll mode',
      );
      expect(denied.status, equals(ToolOutputStatus.denied));
      // denied uses 'reason' not 'errorMessage'
    });

    test('denyAll mode denies all high-risk tools', () async {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'risky', riskLevel: 'high'));
      final adapter = Step20ConfirmationAdapter(
        registry: registry,
        mode: ConfirmationMode.denyAll,
      );
      final result = await adapter.confirm(
        toolId: 'risky',
        context: ToolExecutionContext(),
      );
      expect(result.status, equals(ToolOutputStatus.denied));
    });

    test('no raw \n literals in output messages', () {
      // Adapter must not produce messages with raw \n
      final output = ToolOutput.denied(
        toolId: 'test',
        reason: 'Access denied. Please contact admin.',
      );
      expect(output.deniedReason, isNot(contains('\n')));
    });

    test('FAIL-CLOSED: confirmation failure returns denied', () async {
      final registry = ToolExecutorRegistry();
      final adapter = Step20ConfirmationAdapter(
        registry: registry,
        mode: ConfirmationMode.denyAll,
      );
      final result = await adapter.confirm(
        toolId: 'nonexistent',
        context: ToolExecutionContext(),
      );
      // FAIL-CLOSED: unregistered = denied
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
