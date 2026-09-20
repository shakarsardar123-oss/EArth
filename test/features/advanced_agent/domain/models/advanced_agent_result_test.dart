/// advanced_agent_result_test.dart
/// Structural & mock tests for AdvancedAgentResult model.
///
/// Verifies: class existence, field names, factory constructors,
/// FAIL-CLOSED patterns (unknown→denied, status.isFailure).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/advanced_agent_result.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/advanced_agent_failure.dart';

void main() {
  group('AdvancedAgentResultStatus', () {
    test('fromName returns correct enum for known values', () {
      expect(AdvancedAgentResultStatus.fromName('success'), AdvancedAgentResultStatus.success);
      expect(AdvancedAgentResultStatus.fromName('failed'), AdvancedAgentResultStatus.failed);
      expect(AdvancedAgentResultStatus.fromName('denied'), AdvancedAgentResultStatus.denied);
      expect(AdvancedAgentResultStatus.fromName('cancelled'), AdvancedAgentResultStatus.cancelled);
      expect(AdvancedAgentResultStatus.fromName('offlineDegraded'), AdvancedAgentResultStatus.offlineDegraded);
    });

    test('FAIL-CLOSED: fromName returns unknown for unknown string', () {
      expect(AdvancedAgentResultStatus.fromName('foobar'), AdvancedAgentResultStatus.unknown);
    });

    test('isFailure is true for failed/denied/cancelled/unknown', () {
      expect(AdvancedAgentResultStatus.failed.isFailure, isTrue);
      expect(AdvancedAgentResultStatus.denied.isFailure, isTrue);
      expect(AdvancedAgentResultStatus.cancelled.isFailure, isTrue);
      expect(AdvancedAgentResultStatus.unknown.isFailure, isTrue);
      expect(AdvancedAgentResultStatus.success.isFailure, isFalse);
      expect(AdvancedAgentResultStatus.offlineDegraded.isFailure, isFalse);
    });
  });

  group('AdvancedAgentResult', () {
    test('success factory produces correct status', () {
      final r = AdvancedAgentResult.success(resultId: 'r1');
      expect(r.isSuccess, isTrue);
      expect(r.isFailure, isFalse);
      expect(r.isDegraded, isFalse);
      expect(r.isDenied, isFalse);
      expect(r.locale, 'ku');
    });

    test('denied factory produces denied status', () {
      final r = AdvancedAgentResult.denied(resultId: 'r2');
      expect(r.isDenied, isTrue);
      expect(r.isSuccess, isFalse);
    });

    test('failed factory requires failures list', () {
      final r = AdvancedAgentResult.failed(
        resultId: 'r3',
        failures: [AdvancedAgentFailure.timeout(failureId: 'f1')],
      );
      expect(r.isFailure, isTrue);
      expect(r.failures.length, 1);
    });

    test('cancelled factory includes cancelled failure', () {
      final r = AdvancedAgentResult.cancelled(resultId: 'r4');
      expect(r.status, AdvancedAgentResultStatus.cancelled);
      expect(r.failures, isNotEmpty);
    });

    test('offlineDegraded factory', () {
      final r = AdvancedAgentResult.offlineDegraded(resultId: 'r5');
      expect(r.isDegraded, isTrue);
      expect(r.isSuccess, isFalse);
    });

    test('FAIL-CLOSED: unknown factory produces denied', () {
      final r = AdvancedAgentResult.unknown(resultId: 'r6');
      expect(r.isDenied, isTrue);
      expect(r.status, AdvancedAgentResultStatus.denied);
    });

    test('default locale is ku', () {
      final r = AdvancedAgentResult.success(resultId: 'r7');
      expect(r.locale, 'ku');
    });

    test('hasRecoverableFailures checks failures', () {
      final r1 = AdvancedAgentResult.failed(
        resultId: 'r8',
        failures: [AdvancedAgentFailure.timeout(failureId: 'f2')],
      );
      expect(r1.hasRecoverableFailures, isTrue);

      final r2 = AdvancedAgentResult.failed(
        resultId: 'r9',
        failures: [AdvancedAgentFailure.safetyDenial(failureId: 'f3')],
      );
      expect(r2.hasRecoverableFailures, isFalse);
    });
  });
}
