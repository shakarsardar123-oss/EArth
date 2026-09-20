// Test file for AssistantService abstract contract.
//
// Structural / mock-based tests — verify the contract defines
// the expected methods and the stub implements them correctly.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/features/assistant_integration/domain/assistant_service.dart';
import 'package:aura_assistant/features/assistant_integration/domain/entities/assistant_status.dart';
import 'package:aura_assistant/features/assistant_integration/domain/entities/assistant_invocation.dart';
import 'package:aura_assistant/features/assistant_integration/domain/models/assistant_failure.dart';
import 'package:aura_assistant/features/assistant_integration/infrastructure/stub_assistant_service.dart';

void main() {
  group('AssistantService', () {
    test('StubAssistantService implements AssistantService', () {
      final stub = StubAssistantService();
      expect(stub, isA<AssistantService>());
    });

    test('detectStatus returns configured status by default', () async {
      final stub = StubAssistantService();
      final result = await stub.detectStatus();
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.availability, AssistantAvailability.available);
    });

    test('detectStatus returns failure when configured', () async {
      final failure = AssistantFailure.statusCheckFailed(Exception('fail'));
      final stub = StubAssistantService(detectStatusFailure: failure);
      final result = await stub.detectStatus();
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, failure);
    });

    test('openAssistantSettings succeeds by default', () async {
      final stub = StubAssistantService();
      final result = await stub.openAssistantSettings();
      expect(result.isSuccess, isTrue);
    });

    test('openAssistantSettings returns failure when configured', () async {
      final failure = AssistantFailure.openSettingsFailed(Exception('err'));
      final stub = StubAssistantService(openSettingsFailure: failure);
      final result = await stub.openAssistantSettings();
      expect(result.isFailure, isTrue);
    });

    test('getInvocationData returns configured invocation', () async {
      final now = DateTime(2026, 1, 1);
      const status = AssistantStatus(availability: AssistantAvailability.active);
      final invocation = AssistantInvocation(
        trigger: InvocationTrigger.homeButton,
        invokedAt: now,
        statusAtInvocation: status,
      );
      final stub = StubAssistantService(invocationDataResult: invocation);
      final result = await stub.getInvocationData();
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.trigger, InvocationTrigger.homeButton);
    });

    test('getInvocationData returns failure when none configured', () async {
      final stub = StubAssistantService(); // no invocation configured
      final result = await stub.getInvocationData();
      expect(result.isFailure, isTrue);
    });

    test('getInvocationData returns configured failure', () async {
      final failure = AssistantFailure.invocationParseFailed(Exception('x'));
      final stub = StubAssistantService(getInvocationFailure: failure);
      final result = await stub.getInvocationData();
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, failure);
    });

    test('isAssistantRoleSupported returns true by default', () async {
      final stub = StubAssistantService();
      final result = await stub.isAssistantRoleSupported();
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isTrue);
    });

    test('isAssistantRoleSupported returns configured value', () async {
      final stub = StubAssistantService(isSupportedResult: false);
      final result = await stub.isAssistantRoleSupported();
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isFalse);
    });
  });
}
