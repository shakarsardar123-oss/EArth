/// tool_execution_engine_test.dart
/// AURA Assistant – Step 22: Tests for ToolExecutionEngine
///
/// Structural validation only (no Flutter/Dart SDK).
/// Tests: 6-gate pipeline order, gate pass/fail, fail-closed on
/// any gate failure, EngineExecutionResult, timeout integration,
/// cancellation integration.
library;

import 'package:test/test.dart';
import 'package:aura_assistant/features/tool_execution/tool_execution.dart';

void main() {
  group('ToolExecutionEngine', () {
    test('has 6 gates in pipeline', () {
      final engine = ToolExecutionEngine(
        gateAdapter: Step20GateAdapter(),
        securityBridge: Step19SecurityBridge(),
        retryBridge: Step18RetryBridge(),
        confirmationAdapter: Step20ConfirmationAdapter(),
        discoveryAdapter: Step20DiscoveryAdapter(),
        executorRegistry: ToolExecutorRegistry(),
      );
      expect(engine.gateCount, equals(6));
    });

    test('gates execute in correct order', () {
      final engine = ToolExecutionEngine(
        gateAdapter: Step20GateAdapter(),
        securityBridge: Step19SecurityBridge(),
        retryBridge: Step18RetryBridge(),
        confirmationAdapter: Step20ConfirmationAdapter(),
        discoveryAdapter: Step20DiscoveryAdapter(),
        executorRegistry: ToolExecutorRegistry(),
      );
      final gateNames = engine.gateNames;
      expect(gateNames[0], equals('validation'));
      expect(gateNames[1], equals('security'));
      expect(gateNames[2], equals('confirmation'));
      expect(gateNames[3], equals('readiness'));
      expect(gateNames[4], equals('permission'));
      expect(gateNames[5], equals('execution'));
    });

    test('fail-closed: security gate failure blocks execution', () async {
      final engine = ToolExecutionEngine(
        gateAdapter: Step20GateAdapter(),
        securityBridge: Step19SecurityBridge(denyAll: true),
        retryBridge: Step18RetryBridge(),
        confirmationAdapter: Step20ConfirmationAdapter(),
        discoveryAdapter: Step20DiscoveryAdapter(),
        executorRegistry: ToolExecutorRegistry(),
      );
      final context = ToolExecutionContext(
        executionId: 'exec-denied',
        toolId: 'system',
        action: 'shutdown',
      );
      final result = await engine.execute(context);
      expect(result.status, equals(ToolOutputStatus.failClosed));
    });

    test('fail-closed: confirmation denied blocks execution', () async {
      final engine = ToolExecutionEngine(
        gateAdapter: Step20GateAdapter(),
        securityBridge: Step19SecurityBridge(),
        retryBridge: Step18RetryBridge(),
        confirmationAdapter: Step20ConfirmationAdapter(autoDeny: true),
        discoveryAdapter: Step20DiscoveryAdapter(),
        executorRegistry: ToolExecutorRegistry(),
      );
      final context = ToolExecutionContext(
        executionId: 'exec-noconfirm',
        toolId: 'communication',
        action: 'call_phone',
      );
      final result = await engine.execute(context);
      expect(result.status, equals(ToolOutputStatus.denied));
    });

    test('EngineExecutionResult captures metadata', () async {
      final engine = ToolExecutionEngine(
        gateAdapter: Step20GateAdapter(),
        securityBridge: Step19SecurityBridge(),
        retryBridge: Step18RetryBridge(),
        confirmationAdapter: Step20ConfirmationAdapter(),
        discoveryAdapter: Step20DiscoveryAdapter(),
        executorRegistry: ToolExecutorRegistry(),
      );
      final context = ToolExecutionContext(
        executionId: 'exec-meta',
        toolId: 'device',
        action: 'get_battery',
      );
      final result = await engine.execute(context);
      expect(result.metadata, isNotNull);
      expect(result.metadata.executionId, equals('exec-meta'));
    });

    test('timeout integration cancels execution', () async {
      final engine = ToolExecutionEngine(
        gateAdapter: Step20GateAdapter(),
        securityBridge: Step19SecurityBridge(),
        retryBridge: Step18RetryBridge(),
        confirmationAdapter: Step20ConfirmationAdapter(),
        discoveryAdapter: Step20DiscoveryAdapter(),
        executorRegistry: ToolExecutorRegistry(),
      );
      final context = ToolExecutionContext(
        executionId: 'exec-timeout',
        toolId: 'device',
        action: 'get_battery',
        timeoutMs: 1,
      );
      final result = await engine.execute(context);
      expect(result.status, equals(ToolOutputStatus.timedOut));
    });

    test('cancellation token cancels execution', () async {
      final token = CancellationToken();
      final engine = ToolExecutionEngine(
        gateAdapter: Step20GateAdapter(),
        securityBridge: Step19SecurityBridge(),
        retryBridge: Step18RetryBridge(),
        confirmationAdapter: Step20ConfirmationAdapter(),
        discoveryAdapter: Step20DiscoveryAdapter(),
        executorRegistry: ToolExecutorRegistry(),
      );
      token.cancel('User requested cancellation');
      final context = ToolExecutionContext(
        executionId: 'exec-cancel',
        toolId: 'device',
        action: 'get_battery',
        cancellationToken: token,
      );
      final result = await engine.execute(context);
      expect(result.status, equals(ToolOutputStatus.cancelled));
    });
  });
}
