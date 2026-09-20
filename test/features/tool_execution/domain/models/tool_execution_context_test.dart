/// tool_execution_context_test.dart
/// AURA Assistant – Step 22: Tests for ToolExecutionContext
///
/// Structural validation only (no Flutter/Dart SDK).
/// Tests: construction, canProceed, isTimedOut, cancel,
/// incrementRetry, withSecurityClearance, locale.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/tool_execution/tool_execution.dart';

void main() {
  group('ToolExecutionContext', () {
    test('default context has canProceed=true', () {
      final context = ToolExecutionContext(
        executionId: 'exec-001',
        toolId: 'device',
        caller: 'test',
      );
      expect(context.canProceed, isTrue);
    });

    test('cancelled context has canProceed=false', () {
      final context = ToolExecutionContext(
        executionId: 'exec-002',
        toolId: 'device',
        caller: 'test',
        confirmationDenied: true,
      );
      expect(context.canProceed, isFalse);
    });

    test('isTimedOut returns true when timeout elapsed', () {
      final context = ToolExecutionContext(
        executionId: 'exec-003',
        toolId: 'device',
        caller: 'test',
        timeout: const Duration(milliseconds: -1),
      );
      expect(context.isTimedOut, isTrue);
    });

    test('cancel sets confirmationDenied', () {
      final context = ToolExecutionContext(
        executionId: 'exec-004',
        toolId: 'device',
        caller: 'test',
      );
      context.cancel();
      expect(context.canProceed, isFalse);
    });

    test('incrementRetry increments currentRetries', () {
      final context = ToolExecutionContext(
        executionId: 'exec-005',
        toolId: 'device',
        caller: 'test',
      );
      expect(context.currentRetries, equals(0));
      context.incrementRetry();
      expect(context.currentRetries, equals(1));
      context.incrementRetry();
      expect(context.currentRetries, equals(2));
    });

    test('withSecurityClearance creates new context with clearance', () {
      final context = ToolExecutionContext(
        executionId: 'exec-006',
        toolId: 'system',
        caller: 'test',
      );
      final elevated = context.withSecurityClearance(5);
      expect(elevated.securityClearance, equals(5));
    });

    test('locale defaults to ku (Kurdish Sorani)', () {
      final context = ToolExecutionContext(
        executionId: 'exec-007',
        toolId: 'device',
        caller: 'test',
      );
      expect(context.locale, equals('ku'));
    });

    test('background flag defaults to false', () {
      final context = ToolExecutionContext(
        executionId: 'exec-008',
        toolId: 'device',
        caller: 'test',
      );
      expect(context.isBackground, isFalse);
    });

    test('background flag can be set to true', () {
      final context = ToolExecutionContext(
        executionId: 'exec-009',
        toolId: 'media',
        caller: 'test',
        isBackground: true,
      );
      expect(context.isBackground, isTrue);
    });
  });
}
