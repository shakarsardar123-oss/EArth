import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/reaction/reaction.dart';

void main() {
  group('ReactionContext', () {
    final baseTime = DateTime(2026, 1, 1, 12, 0, 0);

    test('default values', () {
      final ctx = ReactionContext(
        trigger: ReactionTrigger.voiceState,
        timestamp: baseTime,
      );
      expect(ctx.trigger, ReactionTrigger.voiceState);
      expect(ctx.triggerSource, ContextTriggerSource.stateChange);
      expect(ctx.voiceState, isNull);
      expect(ctx.agentState, isNull);
      expect(ctx.intentActionType, isNull);
      expect(ctx.intentConfidence, isNull);
      expect(ctx.urgency, 0.5);
      expect(ctx.userTone, UserTone.unknown);
      expect(ctx.seed, isNull);
    });

    test('isAgentActive', () {
      expect(
        ReactionContext(
          trigger: ReactionTrigger.agentState,
          agentState: 'executing',
          timestamp: baseTime,
        ).isAgentActive,
        isTrue,
      );
      expect(
        ReactionContext(
          trigger: ReactionTrigger.agentState,
          agentState: 'idle',
          timestamp: baseTime,
        ).isAgentActive,
        isFalse,
      );
      expect(
        ReactionContext(
          trigger: ReactionTrigger.agentState,
          timestamp: baseTime,
        ).isAgentActive,
        isFalse,
      );
    });

    test('isVoiceActive', () {
      expect(
        ReactionContext(
          trigger: ReactionTrigger.voiceState,
          voiceState: 'listening',
          timestamp: baseTime,
        ).isVoiceActive,
        isTrue,
      );
      expect(
        ReactionContext(
          trigger: ReactionTrigger.voiceState,
          voiceState: 'idle',
          timestamp: baseTime,
        ).isVoiceActive,
        isFalse,
      );
      expect(
        ReactionContext(
          trigger: ReactionTrigger.voiceState,
          voiceState: 'error',
          timestamp: baseTime,
        ).isVoiceActive,
        isFalse,
      );
    });

    test('isError', () {
      expect(
        ReactionContext(
          trigger: ReactionTrigger.errorEvent,
          voiceState: 'error',
          timestamp: baseTime,
        ).isError,
        isTrue,
      );
      expect(
        ReactionContext(
          trigger: ReactionTrigger.errorEvent,
          agentState: 'failed',
          timestamp: baseTime,
        ).isError,
        isTrue,
      );
      expect(
        ReactionContext(
          trigger: ReactionTrigger.errorEvent,
          agentState: 'idle',
          timestamp: baseTime,
        ).isError,
        isFalse,
      );
    });

    test('copyWith preserves unmodified fields', () {
      final ctx = ReactionContext(
        trigger: ReactionTrigger.voiceState,
        voiceState: 'listening',
        urgency: 0.8,
        timestamp: baseTime,
      );
      final copy = ctx.copyWith(agentState: 'understanding');

      expect(copy.trigger, ReactionTrigger.voiceState);
      expect(copy.voiceState, 'listening');
      expect(copy.agentState, 'understanding');
      expect(copy.urgency, 0.8);
    });

    test('equality', () {
      final ctx1 = ReactionContext(
        trigger: ReactionTrigger.voiceState,
        voiceState: 'listening',
        timestamp: baseTime,
      );
      final ctx2 = ReactionContext(
        trigger: ReactionTrigger.voiceState,
        voiceState: 'listening',
        timestamp: baseTime,
      );
      final ctx3 = ReactionContext(
        trigger: ReactionTrigger.voiceState,
        voiceState: 'speaking',
        timestamp: baseTime,
      );

      expect(ctx1 == ctx2, isTrue);
      expect(ctx1 == ctx3, isFalse);
    });
  });
}
