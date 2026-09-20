// tool_execution_metadata_test.dart — Structural tests for ToolExecutionMetadata
// AuditEntry has NO phase param. ToolExecutionPhase has exactly 12 values.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_execution_metadata.dart';

void main() {
  group('ToolExecutionPhase', () {
    test('has exactly 12 values', () {
      expect(ToolExecutionPhase.values.length, equals(12));
    });

    test('contains all canonical phases', () {
      expect(ToolExecutionPhase.values, containsAll([
        ToolExecutionPhase.requested,
        ToolExecutionPhase.validating,
        ToolExecutionPhase.confirming,
        ToolExecutionPhase.sanitizing,
        ToolExecutionPhase.executing,
        ToolExecutionPhase.normalizing,
        ToolExecutionPhase.completed,
        ToolExecutionPhase.failed,
        ToolExecutionPhase.cancelled,
        ToolExecutionPhase.timedOut,
        ToolExecutionPhase.denied,
        ToolExecutionPhase.failClosed,
      ]));
    });
  });

  group('AuditEntry', () {
    test('AuditEntry has action, description, timestamp — NO phase', () {
      final entry = AuditEntry(
        action: 'validate_input',
        description: 'Input validated successfully',
        timestamp: DateTime.now(),
      );
      expect(entry.action, equals('validate_input'));
      expect(entry.description, equals('Input validated successfully'));
      expect(entry.timestamp, isA<DateTime>());
    });

    test('AuditEntry with optional details', () {
      final entry = AuditEntry(
        action: 'sanitize',
        description: 'Sanitized input',
        timestamp: DateTime.now(),
        details: {'field': 'query', 'original': '<script>'},
      );
      expect(entry.details, isNotNull);
      expect(entry.details!['field'], equals('query'));
    });

    test('AuditEntry immutable methods return new instances', () {
      final original = AuditEntry(
        action: 'test',
        description: 'desc',
        timestamp: DateTime.now(),
      );
      final withDetails = original.withDetails({'extra': 'data'});
      expect(identical(original, withDetails), isFalse);
      expect(withDetails.details, isNotNull);
      expect(original.details, isNull);
    });
  });

  group('ToolExecutionMetadata', () {
    test('creates with toolId and tracks phases', () {
      final metadata = ToolExecutionMetadata(toolId: 'device_tool');
      expect(metadata.toolId, equals('device_tool'));
      expect(metadata.entries, isEmpty);
    });

    test('addEntry appends AuditEntry', () {
      final metadata = ToolExecutionMetadata(toolId: 'test_tool');
      final entry = AuditEntry(
        action: 'start',
        description: 'Execution started',
        timestamp: DateTime.now(),
      );
      final updated = metadata.addEntry(entry);
      expect(updated.entries.length, equals(1));
      expect(metadata.entries.length, equals(0)); // immutable
    });
  });
}
