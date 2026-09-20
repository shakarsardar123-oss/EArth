// Test file for AssistantInvocation entity.
//
// Structural / mock-based tests — verify value semantics,
// copyWith, clear flags, and convenience getters.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/assistant_integration/domain/entities/assistant_invocation.dart';
import 'package:aura_assistant/features/assistant_integration/domain/entities/assistant_status.dart';

void main() {
  final _now = DateTime(2026, 1, 1);
  const _status = AssistantStatus(availability: AssistantAvailability.active);

  group('InvocationTrigger', () {
    test('has five expected values', () {
      expect(InvocationTrigger.values, hasLength(5));
      expect(InvocationTrigger.values, contains(InvocationTrigger.homeButton));
      expect(InvocationTrigger.values, contains(InvocationTrigger.assistantKey));
      expect(InvocationTrigger.values, contains(InvocationTrigger.voiceTrigger));
      expect(InvocationTrigger.values, contains(InvocationTrigger.externalApp));
      expect(InvocationTrigger.values, contains(InvocationTrigger.unknown));
    });
  });

  group('AssistantInvocation', () {
    test('default constructor has unknown trigger', () {
      final invocation = AssistantInvocation(
        invokedAt: _now,
        statusAtInvocation: _status,
      );
      expect(invocation.trigger, InvocationTrigger.unknown);
      expect(invocation.assistContext, isNull);
      expect(invocation.assistUri, isNull);
      expect(invocation.callingPackage, isNull);
    });

    test('hasContext returns true when context is non-empty', () {
      final withContext = AssistantInvocation(
        assistContext: 'Hello AURA',
        invokedAt: _now,
        statusAtInvocation: _status,
      );
      final without = AssistantInvocation(
        invokedAt: _now,
        statusAtInvocation: _status,
      );
      expect(withContext.hasContext, isTrue);
      expect(without.hasContext, isFalse);
    });

    test('hasUri returns true when uri is non-empty', () {
      final withUri = AssistantInvocation(
        assistUri: 'https://example.com',
        invokedAt: _now,
        statusAtInvocation: _status,
      );
      final without = AssistantInvocation(
        invokedAt: _now,
        statusAtInvocation: _status,
      );
      expect(withUri.hasUri, isTrue);
      expect(without.hasUri, isFalse);
    });

    test('isVoiceTriggered is true only for voiceTrigger', () {
      final voice = AssistantInvocation(
        trigger: InvocationTrigger.voiceTrigger,
        invokedAt: _now,
        statusAtInvocation: _status,
      );
      final home = AssistantInvocation(
        trigger: InvocationTrigger.homeButton,
        invokedAt: _now,
        statusAtInvocation: _status,
      );
      expect(voice.isVoiceTriggered, isTrue);
      expect(home.isVoiceTriggered, isFalse);
    });

    test('copyWith updates fields', () {
      final original = AssistantInvocation(
        trigger: InvocationTrigger.homeButton,
        assistContext: 'ctx',
        invokedAt: _now,
        statusAtInvocation: _status,
      );
      final updated = original.copyWith(
        trigger: InvocationTrigger.voiceTrigger,
        callingPackage: 'com.example',
      );

      expect(updated.trigger, InvocationTrigger.voiceTrigger);
      expect(updated.callingPackage, 'com.example');
      // Inherited fields
      expect(updated.assistContext, 'ctx');
    });

    test('copyWith clearAssistContext sets context to null', () {
      final withCtx = AssistantInvocation(
        assistContext: 'some context',
        invokedAt: _now,
        statusAtInvocation: _status,
      );
      final cleared = withCtx.copyWith(clearAssistContext: true);
      expect(cleared.assistContext, isNull);
      expect(cleared.hasContext, isFalse);
    });

    test('copyWith clearAssistUri sets uri to null', () {
      final withUri = AssistantInvocation(
        assistUri: 'https://example.com',
        invokedAt: _now,
        statusAtInvocation: _status,
      );
      final cleared = withUri.copyWith(clearAssistUri: true);
      expect(cleared.assistUri, isNull);
    });

    test('copyWith clearCallingPackage sets package to null', () {
      final withPkg = AssistantInvocation(
        callingPackage: 'com.other',
        invokedAt: _now,
        statusAtInvocation: _status,
      );
      final cleared = withPkg.copyWith(clearCallingPackage: true);
      expect(cleared.callingPackage, isNull);
    });

    test('equality based on key fields', () {
      final a = AssistantInvocation(
        trigger: InvocationTrigger.homeButton,
        assistContext: 'ctx',
        invokedAt: _now,
        statusAtInvocation: _status,
      );
      final b = AssistantInvocation(
        trigger: InvocationTrigger.homeButton,
        assistContext: 'ctx',
        invokedAt: _now,
        statusAtInvocation: _status,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when trigger differs', () {
      final a = AssistantInvocation(
        trigger: InvocationTrigger.homeButton,
        invokedAt: _now,
        statusAtInvocation: _status,
      );
      final b = AssistantInvocation(
        trigger: InvocationTrigger.voiceTrigger,
        invokedAt: _now,
        statusAtInvocation: _status,
      );
      expect(a, isNot(equals(b)));
    });

    test('toString includes key fields', () {
      final invocation = AssistantInvocation(
        trigger: InvocationTrigger.voiceTrigger,
        assistContext: 'hello',
        invokedAt: _now,
        statusAtInvocation: _status,
      );
      expect(invocation.toString(), contains('voiceTrigger'));
      expect(invocation.toString(), contains('hello'));
    });
  });
}
