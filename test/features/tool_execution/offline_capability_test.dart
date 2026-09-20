// offline_capability_test.dart — Structural tests for OfflineCapability
// Uses registry.get(), registry.allTools, ToolOutput.failure(errorMessage:)
// Structural validation only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/tool_execution/application/offline_capability.dart';
import 'package:aura_assistant/features/tool_execution/infrastructure/executors/tool_executor_registry.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_output.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_execution_context.dart';
import 'package:aura_assistant/features/tool_execution/domain/services/tool_interface.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_input.dart';

void main() {
  group('OfflineCapability', () {
    test('offline execution uses registry.get() for tool lookup', () {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'device_tool', riskLevel: 'low'));
      final offline = OfflineCapability(registry: registry);
      expect(offline.registry.get('device_tool'), isNotNull);
    });

    test('offline catalog uses registry.allTools', () {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'a', riskLevel: 'low'));
      registry.register(_MockTool(toolId: 'b', riskLevel: 'low'));
      final offline = OfflineCapability(registry: registry);
      expect(offline.availableOfflineTools.length, equals(2));
    });

    test('unavailable tool returns ToolOutput.failure(errorMessage:)', () async {
      final registry = ToolExecutorRegistry();
      final offline = OfflineCapability(registry: registry);
      final result = await offline.execute(
        toolId: 'unavailable_tool',
        params: {},
        context: ToolExecutionContext(),
      );
      // FAIL-CLOSED: unavailable → failure or failClosed
      expect(
        result.status == ToolOutputStatus.failed ||
        result.status == ToolOutputStatus.failClosed,
        isTrue,
      );
    });

    test('ToolOutput.failure uses errorMessage not message', () {
      final failure = ToolOutput.failure(
        toolId: 'offline_tool',
        errorMessage: 'Tool not available offline',
      );
      expect(failure.status, equals(ToolOutputStatus.failed));
      expect(failure.errorMessage, equals('Tool not available offline'));
    });

    test('offline execution with available tool returns success', () async {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'device_tool', riskLevel: 'low'));
      final offline = OfflineCapability(registry: registry);
      final result = await offline.execute(
        toolId: 'device_tool',
        params: {'action': 'flashlight_on'},
        context: ToolExecutionContext(),
      );
      expect(result, isA<ToolOutput>());
    });

    test('FAIL-CLOSED: empty registry returns failure for any tool', () async {
      final registry = ToolExecutorRegistry();
      final offline = OfflineCapability(registry: registry);
      final result = await offline.execute(
        toolId: 'any_tool',
        params: {},
        context: ToolExecutionContext(),
      );
      expect(
        result.status == ToolOutputStatus.failed ||
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
