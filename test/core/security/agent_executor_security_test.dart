import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/agent/agent_executor.dart';
import 'package:aura_assistant/core/security/tool_security_gate.dart';
import 'package:aura_assistant/core/security/security_policy.dart';
import 'package:aura_assistant/core/security/confirmation_guard.dart';
import 'package:aura_assistant/core/security/security_messages.dart';
import 'package:aura_assistant/core/security/permission_state.dart';
import 'package:aura_assistant/core/permissions/permission_service.dart';
import 'package:aura_assistant/core/tools/tool.dart';
import 'package:aura_assistant/core/tools/tool_definition.dart';
import 'package:aura_assistant/core/tools/tool_arguments.dart';
import 'package:aura_assistant/core/tools/tool_result.dart';
import 'package:aura_assistant/core/tools/tool_registry.dart';
import 'package:aura_assistant/core/tools/tool_permission.dart';
import 'package:aura_assistant/core/agent/agent_confirmation_manager.dart';
import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/core/errors/failures.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

// ── Fakes ──

class FakePermissionService extends PermissionService {
  @override
  Future<bool> isPermissionGranted(ph.Permission permission) async => true;

  @override
  Future<bool> isPermissionPermanentlyDenied(ph.Permission permission) async =>
      false;

  @override
  Future<Result<bool, PermissionFailure>> requestPermission(
      ph.Permission permission) async {
    return Result.failure(PermissionFailure(
      message: 'test',
      code: 'PERMISSION_DENIED',
      permission: permission.toString(),
    ));
  }

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<Map<ph.Permission, bool>> requestAllRequiredPermissions() async =>
      <ph.Permission, bool>{};
}

class FakeTool extends Tool {
  final ToolDefinition _definition;
  ToolResult? _result;
  bool wasExecuted = false;
  ToolArguments? lastArgs;

  FakeTool(
    this._definition, [
    ToolResult result = const ToolResult.success(null),
  ]) : _result = result;

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(ToolArguments arguments) async {
    wasExecuted = true;
    lastArgs = arguments;
    return _result!;
  }
}

class FakeToolRegistry implements ToolRegistry {
  final Map<String, Tool> _tools = {};
  Set<String>? _allowlist;
  bool _enforceAllowlist = false;

  @override
  void register(Tool tool) {
    _tools[tool.definition.name] = tool;
  }

  @override
  void unregister(String name) => _tools.remove(name);

  @override
  Tool? get(String name) => _tools[name];

  @override
  Tool getOrThrow(String name) {
    final tool = _tools[name];
    if (tool == null) {
      throw StateError('Tool not found: $name');
    }
    return tool;
  }

  @override
  bool has(String name) => _tools.containsKey(name);

  @override
  bool isAllowed(String name) {
    if (!_enforceAllowlist) return true;
    if (_allowlist == null) return true;
    return _allowlist!.contains(name);
  }

  @override
  Map<String, dynamic> sanitizeArguments(Map<String, dynamic> args) =>
      Map<String, dynamic>.from(args);

  @override
  List<Tool> get all => _tools.values.toList();

  @override
  List<ToolDefinition> get allDefinitions =>
      _tools.values.map((t) => t.definition).toList();

  @override
  List<Map<String, dynamic>> get openAISchemas =>
      allDefinitions.map((d) => d.toOpenAISchema()).toList();

  @override
  List<Tool> get allowedTools =>
      _tools.values.where((t) => isAllowed(t.definition.name)).toList();

  @override
  List<Tool> getByCategory(String category) =>
      _tools.values.where((t) => t.definition.category == category).toList();

  @override
  List<Tool> getByTags(List<String> tags) =>
      _tools.values.where((t) {
        final toolTags = t.definition.tags;
        return tags.any((tag) => toolTags.contains(tag));
      }).toList();

  @override
  List<Tool> get requiringConfirmation =>
      _tools.values.where((t) => t.definition.needsConfirmation).toList();

  @override
  List<Tool> get dangerous =>
      _tools.values.where((t) => t.definition.isDangerous).toList();

  @override
  int get count => _tools.length;

  @override
  void clear() => _tools.clear();

  @override
  void setAllowlist(Set<String> allowed) {
    _allowlist = Set<String>.from(allowed);
    _enforceAllowlist = true;
  }

  @override
  void clearAllowlist() {
    _allowlist = null;
    _enforceAllowlist = false;
  }

  @override
  void enforceAllowlist() => _enforceAllowlist = true;

  @override
  void disableAllowlist() => _enforceAllowlist = false;
}

// ── Helpers ──

ToolDefinition _def({
  String name = 'test_tool',
  ToolRiskLevel riskLevel = ToolRiskLevel.none,
  List<ToolPermissionRequirement> permissionRequirements = const [],
  bool requiresConfirmation = false,
  Duration timeout = const Duration(seconds: 30),
}) {
  return ToolDefinition(
    name: name,
    description: 'Test tool: $name',
    category: 'general',
    riskLevel: riskLevel,
    permissionRequirements: permissionRequirements,
    requiresConfirmation: requiresConfirmation,
    timeout: timeout,
  );
}

ToolSecurityGate _makeGate() {
  return ToolSecurityGate(
    permissionService: FakePermissionService(),
    securityPolicy: SecurityPolicy(),
    confirmationGuard: ConfirmationGuard(messages: const SecurityMessages()),
    messages: const SecurityMessages(),
  );
}

void main() {
  group('AgentExecutor security integration', () {
    group('tool not in registry', () {
      test('returns failure when tool is not allowed', () async {
        final registry = FakeToolRegistry();
        // Enable allowlist with a different tool so 'missing_tool' is not allowed
        registry.setAllowlist({'other_tool'});
        final executor = AgentExecutor(toolRegistry: registry);
        final result = await executor.executeTool(
          toolName: 'missing_tool',
          arguments: {},
        );
        expect(result.isSuccess, isFalse);
        expect(result.errorCode, 'NOT_ALLOWED');
      });

      test('returns failure when tool is not found', () async {
        final registry = FakeToolRegistry();
        // Allow the tool name but don't register a Tool for it
        registry.setAllowlist({'ghost_tool'});
        final executor = AgentExecutor(toolRegistry: registry);
        final result = await executor.executeTool(
          toolName: 'ghost_tool',
          arguments: {},
        );
        expect(result.isSuccess, isFalse);
        expect(result.errorCode, 'NOT_FOUND');
      });
    });

    group('argument validation', () {
      test('returns failure when tool validation fails', () async {
        final registry = FakeToolRegistry();
        final tool = _ValidatingFakeTool(
          _def(name: 'validating_tool'),
          validationError: 'Argument "name" is required',
        );
        registry.register(tool);
        final executor = AgentExecutor(toolRegistry: registry);
        final result = await executor.executeTool(
          toolName: 'validating_tool',
          arguments: {},
        );
        expect(result.isSuccess, isFalse);
        expect(result.errorCode, 'INVALID_ARGS');
        expect(result.errorMessage, contains('required'));
      });

      test('validation passes but execution is refused without a gate',
          () async {
        final registry = FakeToolRegistry();
        final tool = FakeTool(_def(name: 'pass_tool'));
        registry.register(tool);
        final executor = AgentExecutor(toolRegistry: registry);
        final result = await executor.executeTool(
          toolName: 'pass_tool',
          arguments: {},
        );
        // Argument validation succeeded (no INVALID_ARGS), but the missing
        // security gate must still block execution.
        expect(result.errorCode, 'SECURITY_GATE_MISSING');
        expect(result.isSuccess, isFalse);
      });
    });

    group('security gate — allowed', () {
      test('executes tool when security gate returns allowed', () async {
        final registry = FakeToolRegistry();
        final tool = FakeTool(
          _def(name: 'safe_tool'),
          const ToolResult.success('ok'),
        );
        registry.register(tool);
        final gate = _makeGate();
        final executor = AgentExecutor(
          toolRegistry: registry,
          securityGate: gate,
        );
        final result = await executor.executeTool(
          toolName: 'safe_tool',
          arguments: {},
        );
        expect(result.isSuccess, isTrue);
        expect(tool.wasExecuted, isTrue);
      });

      test('fires onToolCall callback after gate passes', () async {
        final registry = FakeToolRegistry();
        final tool = FakeTool(_def(name: 'cb_tool'));
        registry.register(tool);
        final gate = _makeGate();
        String? calledToolName;
        final executor = AgentExecutor(
          toolRegistry: registry,
          securityGate: gate,
          onToolCall: (name, args) => calledToolName = name,
        );
        await executor.executeTool(
          toolName: 'cb_tool',
          arguments: {},
        );
        expect(calledToolName, 'cb_tool');
      });
    });

    group('security gate — boundary violation', () {
      test('blocks tool execution with boundary violation', () async {
        final registry = FakeToolRegistry();
        final tool = FakeTool(_def(name: 'test_tool'));
        registry.register(tool);
        final gate = _makeGate();
        final executor = AgentExecutor(
          toolRegistry: registry,
          securityGate: gate,
        );
        final result = await executor.executeTool(
          toolName: 'test_tool',
          arguments: {'cmd': 'sh -c rm -rf /'},
        );
        expect(result.isSuccess, isFalse);
        expect(result.errorCode, 'SECURITY_BOUNDARY');
        expect(tool.wasExecuted, isFalse);
      });
    });

    group('security gate — permission denied', () {
      test('blocks tool execution when permissions are denied (non-Android)',
          () async {
        final registry = FakeToolRegistry();
        final tool = FakeTool(_def(
          name: 'mic_tool',
          permissionRequirements: [
            ToolPermissionRequirement(
              permission: ToolPermission.microphone,
              isRequired: true,
            ),
          ],
        ));
        registry.register(tool);
        final gate = _makeGate();
        final executor = AgentExecutor(
          toolRegistry: registry,
          securityGate: gate,
        );
        final result = await executor.executeTool(
          toolName: 'mic_tool',
          arguments: {},
        );
        expect(result.isSuccess, isFalse);
        expect(tool.wasExecuted, isFalse);
      });
    });

    group('security gate — confirmation needed', () {
      test('executes tool when user accepts confirmation', () async {
        final registry = FakeToolRegistry();
        final tool = FakeTool(
          _def(name: 'risky_tool', riskLevel: ToolRiskLevel.high),
          const ToolResult.success('risky result'),
        );
        registry.register(tool);
        final gate = _makeGate();
        final executor = AgentExecutor(
          toolRegistry: registry,
          securityGate: gate,
          onSecurityConfirmation: (request) async => true,
        );
        final result = await executor.executeTool(
          toolName: 'risky_tool',
          arguments: {'key': 'val'},
        );
        expect(result.isSuccess, isTrue);
        expect(tool.wasExecuted, isTrue);
      });

      test('returns failure when user denies confirmation', () async {
        final registry = FakeToolRegistry();
        final tool = FakeTool(
          _def(name: 'denied_tool', riskLevel: ToolRiskLevel.high),
        );
        registry.register(tool);
        final gate = _makeGate();
        final executor = AgentExecutor(
          toolRegistry: registry,
          securityGate: gate,
          onSecurityConfirmation: (request) async => false,
        );
        final result = await executor.executeTool(
          toolName: 'denied_tool',
          arguments: {'key': 'val'},
        );
        expect(result.isSuccess, isFalse);
        expect(result.errorCode, 'CONFIRMATION_DENIED');
        expect(tool.wasExecuted, isFalse);
      });

      test('defaults to denial when no onSecurityConfirmation handler',
          () async {
        final registry = FakeToolRegistry();
        final tool = FakeTool(
          _def(name: 'no_handler_tool', riskLevel: ToolRiskLevel.high),
        );
        registry.register(tool);
        final gate = _makeGate();
        // No onSecurityConfirmation callback
        final executor = AgentExecutor(
          toolRegistry: registry,
          securityGate: gate,
        );
        final result = await executor.executeTool(
          toolName: 'no_handler_tool',
          arguments: {'key': 'val'},
        );
        expect(result.isSuccess, isFalse);
        expect(tool.wasExecuted, isFalse);
      });

      test('confirmation request is passed to handler', () async {
        final registry = FakeToolRegistry();
        final tool = FakeTool(
          _def(name: 'confirm_tool', riskLevel: ToolRiskLevel.critical),
        );
        registry.register(tool);
        final gate = _makeGate();
        ToolConfirmationRequest? capturedRequest;
        final executor = AgentExecutor(
          toolRegistry: registry,
          securityGate: gate,
          onSecurityConfirmation: (request) async {
            capturedRequest = request;
            return true;
          },
        );
        await executor.executeTool(
          toolName: 'confirm_tool',
          arguments: {'key': 'val'},
        );
        expect(capturedRequest, isNotNull);
        expect(capturedRequest!.toolName, 'confirm_tool');
        expect(capturedRequest!.riskLevel, ToolRiskLevel.critical);
      });
    });

    group('security gate — null gate bypasses security', () {
      test('refuses execution when gate is null (fail closed)',
          () async {
        final registry = FakeToolRegistry();
        final tool = FakeTool(
          _def(name: 'free_tool', riskLevel: ToolRiskLevel.critical),
          const ToolResult.success('no gate'),
        );
        registry.register(tool);
        // No security gate
        final executor = AgentExecutor(toolRegistry: registry);
        final result = await executor.executeTool(
          toolName: 'free_tool',
          arguments: {'cmd': 'sh -c rm -rf /'},
        );
        // Without a gate nothing may run: security checks are mandatory.
        expect(result.isSuccess, isFalse);
        expect(result.errorCode, 'SECURITY_GATE_MISSING');
        expect(tool.wasExecuted, isFalse);
      });
    });

    group('execution order', () {
      test('onToolCall fires after security gate passes', () async {
        final registry = FakeToolRegistry();
        final tool = FakeTool(_def(name: 'order_tool'));
        registry.register(tool);
        final gate = _makeGate();
        final events = <String>[];
        final executor = AgentExecutor(
          toolRegistry: registry,
          securityGate: gate,
          onToolCall: (name, args) => events.add('onToolCall'),
          onToolResult: (name, result) => events.add('onToolResult'),
        );
        await executor.executeTool(
          toolName: 'order_tool',
          arguments: {},
        );
        expect(events, ['onToolCall', 'onToolResult']);
      });

      test('onToolCall does not fire when gate blocks execution', () async {
        final registry = FakeToolRegistry();
        final tool = FakeTool(_def(name: 'blocked_tool'));
        registry.register(tool);
        final gate = _makeGate();
        final events = <String>[];
        final executor = AgentExecutor(
          toolRegistry: registry,
          securityGate: gate,
          onToolCall: (name, args) => events.add('onToolCall'),
          onToolResult: (name, result) => events.add('onToolResult'),
        );
        await executor.executeTool(
          toolName: 'blocked_tool',
          arguments: {'cmd': 'sh -c bad'},
        );
        // Gate blocks before onToolCall fires
        expect(events, isEmpty);
      });

      test('onToolResult fires for successful execution', () async {
        final registry = FakeToolRegistry();
        final tool = FakeTool(
          _def(name: 'result_tool'),
          const ToolResult.success('data'),
        );
        registry.register(tool);
        final gate = _makeGate();
        String? resultData;
        final executor = AgentExecutor(
          toolRegistry: registry,
          securityGate: gate,
          onToolResult: (name, result) => resultData = result.data?.toString(),
        );
        await executor.executeTool(
          toolName: 'result_tool',
          arguments: {},
        );
        expect(resultData, 'data');
      });
    });

    group('timeout', () {
      test('returns failure on timeout', () async {
        final registry = FakeToolRegistry();
        final tool = _SlowFakeTool(
          _def(name: 'slow_tool', timeout: const Duration(milliseconds: 50)),
        );
        registry.register(tool);
        final gate = _makeGate();
        final executor = AgentExecutor(
          toolRegistry: registry,
          securityGate: gate,
        );
        final result = await executor.executeTool(
          toolName: 'slow_tool',
          arguments: {},
        );
        expect(result.isSuccess, isFalse);
        expect(result.errorCode, 'TIMEOUT');
      });
    });

    group('execution error', () {
      test('returns failure when tool throws', () async {
        final registry = FakeToolRegistry();
        final tool = _ThrowingFakeTool(_def(name: 'error_tool'));
        registry.register(tool);
        final gate = _makeGate();
        final executor = AgentExecutor(
          toolRegistry: registry,
          securityGate: gate,
        );
        final result = await executor.executeTool(
          toolName: 'error_tool',
          arguments: {},
        );
        expect(result.isSuccess, isFalse);
        expect(result.errorCode, 'EXECUTION_ERROR');
      });
    });
  });
}

// ── Additional fake tools ──

class _ValidatingFakeTool extends Tool {
  final ToolDefinition _definition;
  final String? validationError;

  _ValidatingFakeTool(this._definition, {this.validationError});

  @override
  ToolDefinition get definition => _definition;

  @override
  String? validateArguments(ToolArguments arguments) => validationError;

  @override
  Future<ToolResult> execute(ToolArguments arguments) async =>
      const ToolResult.success(null);
}

class _SlowFakeTool extends Tool {
  final ToolDefinition _definition;

  _SlowFakeTool(this._definition);

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(ToolArguments arguments) async {
    await Future<void>.delayed(const Duration(seconds: 5));
    return const ToolResult.success('late');
  }
}

class _ThrowingFakeTool extends Tool {
  final ToolDefinition _definition;

  _ThrowingFakeTool(this._definition);

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(ToolArguments arguments) async {
    throw Exception('Tool exploded');
  }
}
