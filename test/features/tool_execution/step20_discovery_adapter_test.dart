// step20_discovery_adapter_test.dart — Structural tests for Step20DiscoveryAdapter
// riskLevel String, registry.allTools/get()/byCategory()
// Structural validation only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/tool_execution/infrastructure/adapters/step20_discovery_adapter.dart';
import 'package:aura_assistant/features/tool_execution/infrastructure/executors/tool_executor_registry.dart';
import 'package:aura_assistant/features/tool_execution/domain/services/tool_interface.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_input.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_output.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_execution_context.dart';

void main() {
  group('Step20DiscoveryAdapter', () {
    test('discovers all tools via registry.allTools', () {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'a', riskLevel: 'low'));
      registry.register(_MockTool(toolId: 'b', riskLevel: 'medium'));
      final adapter = Step20DiscoveryAdapter(registry: registry);
      final discovered = adapter.discoverAll();
      expect(discovered.length, equals(2));
    });

    test('gets specific tool via registry.get()', () {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'device_tool', riskLevel: 'low'));
      final adapter = Step20DiscoveryAdapter(registry: registry);
      final tool = adapter.getTool('device_tool');
      expect(tool, isNotNull);
      expect(tool!.toolId, equals('device_tool'));
    });

    test('filters by category via registry.byCategory()', () {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'a', riskLevel: 'low'));
      registry.register(_MockTool(toolId: 'b', riskLevel: 'high'));
      final adapter = Step20DiscoveryAdapter(registry: registry);
      final byCat = adapter.discoverByCategory('default');
      expect(byCat, isA<List<Tool>>());
    });

    test('tool riskLevel is String not enum', () {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 't', riskLevel: 'medium'));
      final adapter = Step20DiscoveryAdapter(registry: registry);
      final tool = adapter.getTool('t');
      expect(tool!.riskLevel, isA<String>());
      expect(tool.riskLevel, equals('medium'));
    });

    test('FAIL-CLOSED: unregistered tool returns null', () {
      final registry = ToolExecutorRegistry();
      final adapter = Step20DiscoveryAdapter(registry: registry);
      final tool = adapter.getTool('nonexistent');
      expect(tool, isNull);
    });

    test('discovery respects registry limits', () {
      final registry = ToolExecutorRegistry();
      final adapter = Step20DiscoveryAdapter(registry: registry);
      expect(adapter.discoverAll(), isEmpty);
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
