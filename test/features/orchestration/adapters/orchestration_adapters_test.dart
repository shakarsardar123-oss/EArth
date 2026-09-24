/// Step 23 — Orchestration Adapter Unit Tests
///
/// Plain-Dart adapter tests (flutter_test harness). No mock library is used
/// — dependencies are either the real pure-Dart subsystems or tiny
/// hand-written fakes, matching the repository style of this codebase.
///
/// Scope: the adapters that are pure-Dart and free of platform channels
/// (Audit, Screen, AgentEngine, Confirmation, Recovery, Security,
/// ToolRegistry, ToolExecution). Adapters that require platform plugins
/// (Permission → permission_handler, Connectivity → connectivity_plus,
/// Voice → STT/TTS, Memory → full MemoryManager) are covered at the
/// integration level and intentionally not unit-tested here.
///
/// NOTE: These tests are authored against the current adapter contracts.
/// The Dart/Flutter SDK is NOT available in this environment, so they have
/// NOT been executed — BUILD/TEST NOT VERIFIED.

import 'package:flutter_test/flutter_test.dart';

import 'package:texo/core/agent/agent_executor.dart'
    show AgentExecutor, CancellationToken;
import 'package:texo/core/agent/agent_recovery.dart' as core_recovery;
import 'package:texo/core/security/security_policy.dart';
import 'package:texo/core/security/confirmation_guard.dart';
import 'package:texo/core/tools/tool_registry.dart';

import 'package:texo/features/orchestration/domain/repositories/repositories.dart';
import 'package:texo/features/orchestration/infrastructure/adapters/adapters.dart';

void main() {
  // ── AuditAdapter (Class D — in-memory) ──────────────────────────
  group('AuditAdapter', () {
    test('record then forRequest returns the matching entry', () async {
      final audit = AuditAdapter();
      final now = DateTime.now();
      await audit.record(
        action: 'orchestration_start',
        description: 'begin',
        timestamp: now,
        details: {'requestId': 'req-1'},
      );
      final entries = await audit.forRequest('req-1');
      expect(entries, hasLength(1));
      expect(entries.first.action, 'orchestration_start');
    });

    test('forRequest isolates entries by requestId', () async {
      final audit = AuditAdapter();
      await audit.record(
        action: 'a',
        description: 'd',
        timestamp: DateTime.now(),
        details: {'requestId': 'req-A'},
      );
      await audit.record(
        action: 'b',
        description: 'd',
        timestamp: DateTime.now(),
        details: {'requestId': 'req-B'},
      );
      expect(await audit.forRequest('req-A'), hasLength(1));
      expect(await audit.forRequest('req-B'), hasLength(1));
      expect(await audit.forRequest('missing'), isEmpty);
    });
  });

  // ── ScreenAdapter (Class C — blocked, must FAIL HONESTLY) ──────────
  // A blocked side-effecting adapter must never pretend an action ran.
  group('ScreenAdapter', () {
    test('executeAction fails closed (does not fake success)', () async {
      final screen = ScreenAdapter();
      final result = await screen.executeAction('tap', {'x': 1, 'y': 2});
      expect(result.succeeded, isFalse,
          reason: 'no dispatcher exists — must not report success');
      expect(result.errorMessage, isNotNull);
      // resultData is String? — never a Map.
      expect(result.resultData, isNull);
    });

    test('isAvailable reports unavailable (fail-closed)', () async {
      expect(await ScreenAdapter().isAvailable(), isFalse);
    });
  });

  // ── AgentEngineAdapter (Class C — blocked placeholders) ────────────
  group('AgentEngineAdapter', () {
    test('understand returns a non-null intent echoing the request', () async {
      final engine = AgentEngineAdapter();
      final intent = await engine.understand('turn on wifi', 'ku');
      expect(intent, isNotNull);
      expect(intent!.rawText, 'turn on wifi');
      expect(intent.locale, 'ku');
    });

    test('plan reflects the intent tool/screen flags and requiresTool maps',
        () async {
      final engine = AgentEngineAdapter();
      final intent = await engine.understand('do something', 'ku');
      final plan = await engine.plan(intent!, null);
      expect(plan, isNotNull);
      expect(engine.requiresTool(plan!), plan.needsTool);
      expect(engine.requiresScreenAction(plan), plan.needsScreenAction);
    });
  });

  // ── ConfirmationAdapter (Class B wired — fail-closed contract) ──────
  group('ConfirmationAdapter', () {
    ConfirmationAdapter build() => ConfirmationAdapter(ConfirmationGuard());

    test('none / low risk auto-approves', () async {
      final adapter = build();
      final none = await adapter.checkAndObtain(
        toolId: 't', riskLevel: 'none', userRequest: 'r');
      final low = await adapter.checkAndObtain(
        toolId: 't', riskLevel: 'low', userRequest: 'r');
      expect(none.obtained, isTrue);
      expect(none.mode, ConfirmationMode.autoApprove);
      expect(low.obtained, isTrue);
    });

    test('high / critical / unknown risk is NOT auto-approved (fail-closed)',
        () async {
      final adapter = build();
      for (final risk in ['high', 'critical', 'definitely-not-a-risk']) {
        final v = await adapter.checkAndObtain(
          toolId: 't', riskLevel: risk, userRequest: 'r');
        expect(v.obtained, isFalse, reason: 'risk=$risk must not auto-approve');
        expect(v.mode, isNot(ConfirmationMode.autoApprove));
      }
    });

    test('isAvailable is true', () async {
      expect(await build().isAvailable(), isTrue);
    });
  });

  // ── RecoveryAdapter (Class B wired — decision delegation) ──────────
  group('RecoveryAdapter', () {
    RecoveryAdapter build() =>
        RecoveryAdapter(core_recovery.AgentRecovery());

    test('executeStrategy(abort) reports not-recoverable', () async {
      final recovered =
          await build().executeStrategy(RecoveryStrategy.abort());
      expect(recovered, isFalse);
    });

    test('executeStrategy(retry) with attempts left is actionable', () async {
      final recovered = await build().executeStrategy(
        RecoveryStrategy.retry(currentAttempt: 0, maxRetries: 3),
      );
      expect(recovered, isTrue);
    });

    test('classifyAndStrategize never throws and returns a strategy',
        () async {
      final strategy = await build().classifyAndStrategize(
        failureType: 'timeout',
        errorMessage: 'network timed out',
        retryAttempt: 0,
      );
      expect(strategy, isA<RecoveryStrategy>());
    });

    test('isAvailable is true', () async {
      expect(await build().isAvailable(), isTrue);
    });
  });

  // ── SecurityAdapter (Class B wired — allowlist boundary) ──────────
  group('SecurityAdapter', () {
    test('unknown tool is denied (fail-closed allowlist)', () async {
      final adapter = SecurityAdapter(SecurityPolicy(), ToolRegistry());
      final verdict =
          await adapter.check('invoke', 'nonexistent_tool', 'low');
      expect(verdict.allowed, isFalse);
      expect(verdict.policyId, 'allowlist');
    });

    test('isAvailable is true', () async {
      final adapter = SecurityAdapter(SecurityPolicy(), ToolRegistry());
      expect(await adapter.isAvailable(), isTrue);
    });
  });

  // ── ToolRegistryAdapter (Class A wired — discovery) ──────────────
  group('ToolRegistryAdapter', () {
    test('empty registry discovers no tools', () async {
      final adapter = ToolRegistryAdapter(ToolRegistry());
      expect(await adapter.discover(null, 'anything'), isEmpty);
    });

    test('selectBest of empty candidates is null (fail-closed)', () async {
      final adapter = ToolRegistryAdapter(ToolRegistry());
      expect(await adapter.selectBest(const [], 'anything'), isNull);
    });
  });

  // ── ToolExecutionAdapter (Class B wired — cancellation gate) ───────
  group('ToolExecutionAdapter', () {
    test('a pre-cancelled token yields a cancelled result (never executes)',
        () async {
      final token = CancellationToken()..cancel();
      final executor = AgentExecutor(toolRegistry: ToolRegistry());
      final adapter = ToolExecutionAdapter(executor, token);
      final result = await adapter.execute(
        toolId: 'any',
        action: 'run',
        parameters: const {},
      );
      expect(result.wasCancelled, isTrue);
    });

    test('cancel() flips the shared token', () async {
      final token = CancellationToken();
      final executor = AgentExecutor(toolRegistry: ToolRegistry());
      final adapter = ToolExecutionAdapter(executor, token);
      await adapter.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('isAvailable is true', () async {
      final adapter = ToolExecutionAdapter(
        AgentExecutor(toolRegistry: ToolRegistry()),
        CancellationToken(),
      );
      expect(await adapter.isAvailable(), isTrue);
    });
  });
}
