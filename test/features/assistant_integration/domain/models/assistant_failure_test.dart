// Test file for AssistantFailure model.
//
// Structural / mock-based tests — verify factory constructors, phase
// assignment, and asFailure() wrapping.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/features/assistant_integration/domain/models/assistant_failure.dart';

void main() {
  group('AssistantPhase', () {
    test('has six expected values', () {
      expect(AssistantPhase.values, hasLength(6));
      expect(AssistantPhase.values, contains(AssistantPhase.detection));
      expect(AssistantPhase.values, contains(AssistantPhase.statusCheck));
      expect(AssistantPhase.values, contains(AssistantPhase.openSettings));
      expect(AssistantPhase.values, contains(AssistantPhase.invocation));
      expect(AssistantPhase.values, contains(AssistantPhase.pipelineRouting));
      expect(AssistantPhase.values, contains(AssistantPhase.voiceInvocation));
    });
  });

  group('AssistantFailure', () {
    test('unsupportedPlatform sets detection phase', () {
      final failure = AssistantFailure.unsupportedPlatform();
      expect(failure.phase, AssistantPhase.detection);
      expect(failure.message, contains('not supported'));
      expect(failure.cause, isNull);
    });

    test('unsupportedPlatform with apiLevel includes it in message', () {
      final failure = AssistantFailure.unsupportedPlatform(apiLevel: 21);
      expect(failure.phase, AssistantPhase.detection);
      expect(failure.message, contains('21'));
    });

    test('statusCheckFailed sets statusCheck phase with cause', () {
      final cause = Exception('channel error');
      final failure = AssistantFailure.statusCheckFailed(cause);
      expect(failure.phase, AssistantPhase.statusCheck);
      expect(failure.cause, cause);
    });

    test('openSettingsFailed sets openSettings phase', () {
      final cause = StateError('activity not found');
      final failure = AssistantFailure.openSettingsFailed(cause);
      expect(failure.phase, AssistantPhase.openSettings);
      expect(failure.cause, cause);
    });

    test('invocationParseFailed sets invocation phase', () {
      const cause = FormatException('bad data');
      final failure = AssistantFailure.invocationParseFailed(cause);
      expect(failure.phase, AssistantPhase.invocation);
    });

    test('pipelineRoutingFailed sets pipelineRouting phase', () {
      final cause = StateError('agent error');
      final failure = AssistantFailure.pipelineRoutingFailed(cause);
      expect(failure.phase, AssistantPhase.pipelineRouting);
    });

    test('voiceInvocationFailed sets voiceInvocation phase', () {
      final cause = Exception('tts failed');
      final failure = AssistantFailure.voiceInvocationFailed(cause);
      expect(failure.phase, AssistantPhase.voiceInvocation);
    });

    test('asFailure wraps as Result.failure', () {
      final failure = AssistantFailure.unsupportedPlatform();
      final result = failure.asFailure<String>();
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, failure);
    });

    test('toString includes phase and message', () {
      final failure = AssistantFailure.unsupportedPlatform();
      expect(failure.toString(), contains('detection'));
      expect(failure.toString(), contains('not supported'));
    });
  });
}
