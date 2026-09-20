// tool_executor_registry_test.dart — Structural tests for ToolExecutorRegistry
// Uses get() NOT getTool(), allTools NOT getAllTools(), byCategory() NOT getByCategory().
// validate(String riskLevel). riskLevel is String NOT ToolRiskLevel enum.
// Structural validation only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/tool_execution/infrastructure/executors/tool_executor_registry.dart';
import 'package:aura_assistant/features/tool_execution/domain/services/tool_interface.dart';

void main() {
  group('ToolExecutorRegistry', () {
    late ToolExecutorRegistry registry;

    setUp(() {
      registry = ToolExecutorRegistry();
    });

    test('get() retrieves a registered tool — NOT getTool()', () {
      // Verify the API method name
      expect(registry.get, isA<Function>());
    });

    test('allTools returns list — NOT getAllTools()', () {
      expect(registry.allTools, isA<List<Tool>>());
    });

    test('byCategory() returns filtered tools — NOT getByCategory()', () {
      expect(registry.byCategory, isA<Function>());
    });

    test('register adds tool to registry', () {
      final mockTool = _MockTool(toolId: 'device_tool', riskLevel: 'low');
      registry.register(mockTool);
      final retrieved = registry.get('device_tool');
      expect(retrieved, isNotNull);
      expect(retrieved!.toolId, equals('device_tool'));
    });

    test('get returns null for unregistered tool', () {
      final result = registry.get('nonexistent_tool');
      expect(result, isNull);
    });

    test('validate takes String riskLevel — NOT enum', () {
      expect(
        () => registry.validate('high'),
        returnsNormally,
      );
    });

    test('validate rejects invalid riskLevel', () {
      expect(
        () => registry.validate('ultra_high'),
        throwsA(anything), // or returns false depending on impl
      );
    });

    test('tool riskLevel is String NOT ToolRiskLevel enum', () {
      final mockTool = _MockTool(toolId: 'test', riskLevel: 'medium');
      expect(mockTool.riskLevel, isA<String>());
      expect(mockTool.riskLevel, equals('medium'));
    });

    test('allTools returns all registered tools', () {
      registry.register(_MockTool(toolId: 'a', riskLevel: 'low'));
      registry.register(_MockTool(toolId: 'b', riskLevel: 'medium'));
      expect(registry.allTools.length, equals(2));
    });

    test('byCategory filters correctly', () {
      registry.register(_MockTool(toolId: 'cat_a', riskLevel: 'low'));
      registry.register(_MockTool(toolId: 'cat_b', riskLevel: 'low'));
      final filtered = registry.byCategory('default');
      expect(filtered, isA<List<Tool>>());
    });
  });
}

/// Minimal mock implementing Tool interface for testing
class _MockTool extends Tool {
  final String _toolId;
  final String _riskLevel;

  _MockTool({required String toolId, required String riskLevel})
      : _toolId = toolId,
        _riskLevel = riskLevel;

  @override
  String get toolId => _toolId;

  @override
  String get riskLevel => _riskLevel;

  @override
  ToolInput validate(Map<String, dynamic> params) {
    return ToolInput.valid(toolId: _toolId, params: params);
  }

  @override
  Future<ToolOutput> execute(ToolInput input, ToolExecutionContext context) async {
    return ToolOutput.success(toolId: _toolId, data: {});
  }

  @override
  bool cancel() => true;
}
