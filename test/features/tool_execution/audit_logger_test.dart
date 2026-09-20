// audit_logger_test.dart — Structural tests for AuditLogger
// Uses 12 canonical ToolExecutionPhase values. AuditEntry has NO phase param.
// Structural validation only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/tool_execution/infrastructure/audit_logger.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_execution_metadata.dart';

void main() {
  group('AuditLogger', () {
    test('log creates AuditEntry with action, description, timestamp — NO phase', () {
      final logger = AuditLogger();
      logger.log(
        action: 'validate_input',
        description: 'Input params validated',
        toolId: 'device_tool',
      );
      final entries = logger.entries;
      expect(entries.length, equals(1));
      expect(entries.first.action, equals('validate_input'));
      expect(entries.first.description, equals('Input params validated'));
      expect(entries.first.timestamp, isA<DateTime>());
      // AuditEntry has no phase
    });

    test('log with details', () {
      final logger = AuditLogger();
      logger.log(
        action: 'sanitize',
        description: 'Sanitized input',
        toolId: 'test_tool',
        details: {'field': 'query', 'original': '<script>'},
      );
      expect(logger.entries.first.details, isNotNull);
    });

    test('logPhase maps to canonical 12 phases', () {
      final logger = AuditLogger();
      logger.logPhase(
        phase: ToolExecutionPhase.validating,
        toolId: 'device_tool',
        description: 'Validating tool input',
      );
      expect(logger.entries.length, equals(1));
      expect(logger.entries.first.action, equals('phase:validating'));
    });

    test('all 12 canonical phases can be logged', () {
      final logger = AuditLogger();
      final phases = ToolExecutionPhase.values;
      expect(phases.length, equals(12));
      for (final phase in phases) {
        logger.logPhase(
          phase: phase,
          toolId: 'test_tool',
          description: 'Phase ${phase.name}',
        );
      }
      expect(logger.entries.length, equals(12));
    });

    test('clear removes all entries', () {
      final logger = AuditLogger();
      logger.log(action: 'a', description: 'd', toolId: 't');
      expect(logger.entries.length, equals(1));
      logger.clear();
      expect(logger.entries.length, equals(0));
    });

    test('FAIL-CLOSED: log on error does not throw', () {
      final logger = AuditLogger();
      expect(
        () => logger.log(action: 'error_test', description: 'test', toolId: 'fail_tool'),
        returnsNormally,
      );
    });
  });
}
