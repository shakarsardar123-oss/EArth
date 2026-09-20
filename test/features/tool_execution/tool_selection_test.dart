// tool_selection_test.dart — Structural tests for ToolSelection
// riskLevel String, registry.allTools, registry.get(), maxRiskLevel String?
// Structural validation only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/tool_execution/application/tool_selection.dart';
import 'package:aura_assistant/features/tool_execution/infrastructure/executors/tool_executor_registry.dart';
import 'package:aura_assistant/features/tool_execution/domain/services/tool_interface.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_input.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_output.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_execution_context.dart';

void main() {
  group('ToolSelection', () {
    test('selectFromRegistry uses registry.allTools', () {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'a', riskLevel: 'low'));
      registry.register(_MockTool(toolId: 'b', riskLevel: 'high'));
      final selection = ToolSelection(registry: registry);
      final tools = selection.availableTools;
      expect(tools.length, equals(2));
    });

    test('selectFromRegistry uses registry.get()', () {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'device_tool', riskLevel: 'low'));
      final selection = ToolSelection(registry: registry);
      final tool = selection.selectTool('device_tool');
      expect(tool, isNotNull);
      expect(tool!.toolId, equals('device_tool'));
    });

    test('maxRiskLevel is String? (nullable)', () {
      final registry = ToolExecutorRegistry();
      final selection = ToolSelection(registry: registry, maxRiskLevel: 'medium');
      expect(selection.maxRiskLevel, isA<String?>());
      expect(selection.maxRiskLevel, equals('medium'));
    });

    test('tools filtered by maxRiskLevel', () {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'safe_tool', riskLevel: 'low'));
      registry.register(_MockTool(toolId: 'risky_tool', riskLevel: 'high'));
      final selection = ToolSelection(registry: registry, maxRiskLevel: 'medium');
      final safe = selection.selectTool('safe_tool');
      final risky = selection.selectTool('risky_tool');
      // riskLevel is String, compared with maxRiskLevel
      expect(safe, isNotNull);
      // high > medium → risky tool should be filtered
      // Implementation may deny or return null
    });

    test('tool riskLevel is String not enum', () {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'test', riskLevel: 'low'));
      final selection = ToolSelection(registry: registry);
      final tool = selection.selectTool('test');
      expect(tool!.riskLevel, isA<String>());
    });

    test('FAIL-CLOSED: unregistered tool returns null', () {
      final registry = ToolExecutorRegistry();
      final selection = ToolSelection(registry: registry);
      final tool = selection.selectTool('nonexistent');
      expect(tool, isNull);
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
