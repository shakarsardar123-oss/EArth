// Test file for StubAssistantService.
//
// Structural / mock-based tests — verify all stub methods return
// configured results, call counts are tracked, and failure
// injection works correctly.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/features/assistant_integration/domain/entities/assistant_status.dart';
import 'package:aura_assistant/features/assistant_integration/domain/entities/assistant_invocation.dart';
import 'package:aura_assistant/features/assistant_integration/domain/models/assistant_failure.dart';
import 'package:aura_assistant/features/assistant_integration/infrastructure/stub_assistant_service.dart';

void main() {
  group('StubAssistantService', () {
    test('detectStatus returns success with available by default', () async {
      final stub = StubAssistantService();
      final result = await stub.detectStatus();
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.availability, AssistantAvailability.available);
    });

    test('detectStatus tracks call count', () async {
      final stub = StubAssistantService();
      expect(stub.detectStatusCallCount, 0);
      await stub.detectStatus();
      expect(stub.detectStatusCallCount, 1);
      await stub.detectStatus();
      expect(stub.detectStatusCallCount, 2);
    });

    test('detectStatus returns configured failure', () async {
      final failure = AssistantFailure.statusCheckFailed(Exception('test'));
      final stub = StubAssistantService(detectStatusFailure: failure);
      final result = await stub.detectStatus();
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, failure);
    });

    test('openAssistantSettings returns success by default', () async {
      final stub = StubAssistantService();
      final result = await stub.openAssistantSettings();
      expect(result.isSuccess, isTrue);
    });

    test('openAssistantSettings tracks call count', () async {
      final stub = StubAssistantService();
      expect(stub.openSettingsCallCount, 0);
      await stub.openAssistantSettings();
      expect(stub.openSettingsCallCount, 1);
    });

    test('openAssistantSettings returns configured failure', () async {
      final failure = AssistantFailure.openSettingsFailed(Exception('test'));
      final stub = StubAssistantService(openSettingsFailure: failure);
      final result = await stub.openAssistantSettings();
      expect(result.isFailure, isTrue);
    });

    test('getInvocationData returns failure by default (no data)', () async {
      final stub = StubAssistantService();
      final result = await stub.getInvocationData();
      expect(result.isFailure, isTrue);
    });

    test('getInvocationData returns configured invocation', () async {
      final now = DateTime(2026, 1, 1);
      final invocation = AssistantInvocation(
        trigger: InvocationTrigger.voice,
        invokedAt: now,
        statusAtInvocation: const AssistantStatus(),
      );
      final stub = StubAssistantService(invocationDataResult: invocation);
      final result = await stub.getInvocationData();
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.trigger, InvocationTrigger.voice);
    });

    test('getInvocationData tracks call count', () async {
      final stub = StubAssistantService();
      expect(stub.getInvocationCallCount, 0);
      await stub.getInvocationData();
      expect(stub.getInvocationCallCount, 1);
    });

    test('getInvocationData returns configured failure', () async {
      final failure = AssistantFailure.invocationParseFailed(Exception('x'));
      final stub = StubAssistantService(getInvocationFailure: failure);
      final result = await stub.getInvocationData();
      expect(result.isFailure, isTrue);
    });

    test('isAssistantRoleSupported returns true by default', () async {
      final stub = StubAssistantService();
      final result = await stub.isAssistantRoleSupported();
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isTrue);
    });

    test('isAssistantRoleSupported returns configured result', () async {
      final stub = StubAssistantService(isSupportedResult: false);
      final result = await stub.isAssistantRoleSupported();
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isFalse);
    });

    test('isAssistantRoleSupported tracks call count', () async {
      final stub = StubAssistantService();
      expect(stub.isSupportedCallCount, 0);
      await stub.isAssistantRoleSupported();
      expect(stub.isSupportedCallCount, 1);
    });
  });
}
