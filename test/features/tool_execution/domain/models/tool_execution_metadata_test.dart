/// tool_execution_metadata_test.dart
/// AURA Assistant – Step 22: Tests for ToolExecutionMetadata
///
/// Structural validation only (no Flutter/Dart SDK).
/// Tests: construction, phase enum, gate tracking, audit entries,
/// recovery strategy.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:texo/features/tool_execution/tool_execution.dart';

void main() {
  group('ToolExecutionMetadata', () {
    test('default metadata has zero gates', () {
      final meta = ToolExecutionMetadata(
        executionId: 'exec-001',
        toolId: 'device',
      );
      expect(meta.gatesPassed, equals(0));
      expect(meta.totalGates, equals(6));
      expect(meta.auditEntries, isEmpty);
    });

    test('ToolExecutionPhase has all 12 phases', () {
      expect(ToolExecutionPhase.values.length, equals(12));
      expect(ToolExecutionPhase.values, contains(ToolExecutionPhase.initialization));
      expect(ToolExecutionPhase.values, contains(ToolExecutionPhase.validation));
      expect(ToolExecutionPhase.values, contains(ToolExecutionPhase.securityCheck));
      expect(ToolExecutionPhase.values, contains(ToolExecutionPhase.confirmation));
      expect(ToolExecutionPhase.values, contains(ToolExecutionPhase.readiness));
      expect(ToolExecutionPhase.values, contains(ToolExecutionPhase.permission));
      expect(ToolExecutionPhase.values, contains(ToolExecutionPhase.execution));
      expect(ToolExecutionPhase.values, contains(ToolExecutionPhase.normalization));
      expect(ToolExecutionPhase.values, contains(ToolExecutionPhase.cancellation));
      expect(ToolExecutionPhase.values, contains(ToolExecutionPhase.timeout));
      expect(ToolExecutionPhase.values, contains(ToolExecutionPhase.retry));
      expect(ToolExecutionPhase.values, contains(ToolExecutionPhase.recovery));
    });

    test('audit entries can be added and retrieved', () {
      final meta = ToolExecutionMetadata(
        executionId: 'exec-002',
        toolId: 'system',
      );
      meta.addAuditEntry(AuditEntry(
        phase: ToolExecutionPhase.securityCheck,
        action: 'SECURITY_ALLOWED',
        detail: 'Clearance level sufficient',
      ));
      expect(meta.auditEntries.length, equals(1));
      expect(meta.auditEntries.first.action, equals('SECURITY_ALLOWED'));
    });

    test('phase durations are tracked', () {
      final meta = ToolExecutionMetadata(
        executionId: 'exec-003',
        toolId: 'voice',
      );
      meta.setPhaseDuration(ToolExecutionPhase.execution, const Duration(milliseconds: 150));
      expect(
        meta.getPhaseDuration(ToolExecutionPhase.execution),
        equals(const Duration(milliseconds: 150)),
      );
    });

    test('recovery strategy is nullable', () {
      final meta = ToolExecutionMetadata(
        executionId: 'exec-004',
        toolId: 'device',
      );
      expect(meta.recoveryStrategy, isNull);
      meta.recoveryStrategy = 'retry_with_backoff';
      expect(meta.recoveryStrategy, equals('retry_with_backoff'));
    });
  });
}
