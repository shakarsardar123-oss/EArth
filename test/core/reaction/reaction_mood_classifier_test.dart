import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/reaction/reaction.dart';

void main() {
  // Helper: build a minimal context.
  ReactionContext ctx({
    ReactionTrigger trigger = ReactionTrigger.voiceState,
    String? voiceState,
    String? agentState,
    double urgency = 0.5,
    UserTone userTone = UserTone.unknown,
    double? intentConfidence,
  }) {
    return ReactionContext(
      trigger: trigger,
      voiceState: voiceState,
      agentState: agentState,
      urgency: urgency,
      userTone: userTone,
      intentConfidence: intentConfidence,
      timestamp: DateTime(2025, 1, 1),
    );
  }

  group('ReactionMoodAnalysis', () {
    test('unknown default values', () {
      const analysis = ReactionMoodAnalysis.unknown;
      expect(analysis.mood, ReactionMoodHint.none);
      expect(analysis.urgencyLevel, ReactionUrgencyClass.normal);
      expect(analysis.playfulnessLevel, 0.5);
      expect(analysis.confidence, 0.0);
      expect(analysis.detectedSignals, isEmpty);
    });

    test('equality', () {
      const a = ReactionMoodAnalysis.unknown;
      const b = ReactionMoodAnalysis.unknown;
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('ReactionUrgencyClass', () {
    test('fromValue classifies correctly', () {
      expect(ReactionUrgencyClass.fromValue(0.0), ReactionUrgencyClass.low);
      expect(ReactionUrgencyClass.fromValue(0.24), ReactionUrgencyClass.low);
      expect(ReactionUrgencyClass.fromValue(0.25), ReactionUrgencyClass.normal);
      expect(ReactionUrgencyClass.fromValue(0.49), ReactionUrgencyClass.normal);
      expect(ReactionUrgencyClass.fromValue(0.50), ReactionUrgencyClass.high);
      expect(ReactionUrgencyClass.fromValue(0.74), ReactionUrgencyClass.high);
      expect(ReactionUrgencyClass.fromValue(0.75), ReactionUrgencyClass.critical);
      expect(ReactionUrgencyClass.fromValue(1.0), ReactionUrgencyClass.critical);
    });

    test('weight ordering', () {
      expect(ReactionUrgencyClass.low.weight, lessThan(ReactionUrgencyClass.normal.weight));
      expect(ReactionUrgencyClass.normal.weight, lessThan(ReactionUrgencyClass.high.weight));
      expect(ReactionUrgencyClass.high.weight, lessThan(ReactionUrgencyClass.critical.weight));
    });
  });

  group('ReactionMoodClassifier', () {
    late ReactionMoodClassifier classifier;

    setUp(() {
      classifier = const ReactionMoodClassifier();
    });

    // Rule 1: Error trigger / states → stressed
    test('error trigger → stressed', () {
      final analysis = classifier.classify(ctx(
        trigger: ReactionTrigger.errorEvent,
      ));
      expect(analysis.mood, ReactionMoodHint.stressed);
      expect(analysis.detectedSignals, contains('error_state'));
    });

    test('error voice state → stressed', () {
      final analysis = classifier.classify(ctx(
        voiceState: 'error',
      ));
      expect(analysis.mood, ReactionMoodHint.stressed);
    });

    // Rule 2: Failed agent → stressed
    test('failed agent state → stressed', () {
      final analysis = classifier.classify(ctx(
        agentState: 'failed',
      ));
      expect(analysis.mood, ReactionMoodHint.stressed);
      expect(analysis.detectedSignals, contains('agent_failed'));
    });

    // Rule 3: Frustrated tone → stressed
    test('frustrated user tone → stressed', () {
      final analysis = classifier.classify(ctx(
        userTone: UserTone.frustrated,
      ));
      expect(analysis.mood, ReactionMoodHint.stressed);
      expect(analysis.detectedSignals, contains('frustrated_tone'));
    });

    // Rule 4: Completed agent → upbeat
    test('completed agent state → upbeat', () {
      final analysis = classifier.classify(ctx(
        agentState: 'completed',
      ));
      expect(analysis.mood, ReactionMoodHint.upbeat);
      expect(analysis.detectedSignals, contains('agent_completed'));
    });

    // Rule 5: Wake event → upbeat
    test('wake event → upbeat', () {
      final analysis = classifier.classify(ctx(
        trigger: ReactionTrigger.wakeEvent,
      ));
      expect(analysis.mood, ReactionMoodHint.upbeat);
      expect(analysis.detectedSignals, contains('wake_event'));
    });

    // Rule 6: Happy tone → upbeat
    test('happy user tone → upbeat', () {
      final analysis = classifier.classify(ctx(
        userTone: UserTone.happy,
      ));
      expect(analysis.mood, ReactionMoodHint.upbeat);
      expect(analysis.detectedSignals, contains('happy_tone'));
    });

    // Stress overrides upbeat
    test('error + happy tone → stressed (stress wins)', () {
      final analysis = classifier.classify(ctx(
        trigger: ReactionTrigger.errorEvent,
        userTone: UserTone.happy,
      ));
      expect(analysis.mood, ReactionMoodHint.stressed);
    });

    // Rule 7: Executing agent → focused
    test('executing agent state → focused', () {
      final analysis = classifier.classify(ctx(
        agentState: 'executing',
      ));
      expect(analysis.mood, ReactionMoodHint.focused);
    });

    test('planning agent state → focused', () {
      final analysis = classifier.classify(ctx(
        agentState: 'planning',
      ));
      expect(analysis.mood, ReactionMoodHint.focused);
    });

    test('understanding agent state → focused', () {
      final analysis = classifier.classify(ctx(
        agentState: 'understanding',
      ));
      expect(analysis.mood, ReactionMoodHint.focused);
    });

    // Rule 8: Idle timeout → relaxed
    test('idle timeout → relaxed', () {
      final analysis = classifier.classify(ctx(
        trigger: ReactionTrigger.idleTimeout,
      ));
      expect(analysis.mood, ReactionMoodHint.relaxed);
    });

    // Rule 9: Low confidence → curious
    test('low intent confidence → curious', () {
      final analysis = classifier.classify(ctx(
        intentConfidence: 0.2,
      ));
      expect(analysis.mood, ReactionMoodHint.curious);
    });

    test('confused user tone → curious', () {
      final analysis = classifier.classify(ctx(
        userTone: UserTone.confused,
      ));
      expect(analysis.mood, ReactionMoodHint.curious);
    });

    // Rule 10: Default → none
    test('neutral context → none mood', () {
      final analysis = classifier.classify(ctx(
        trigger: ReactionTrigger.voiceState,
        voiceState: 'idle',
        userTone: UserTone.neutral,
      ));
      expect(analysis.mood, ReactionMoodHint.none);
    });

    // Playfulness adjustments
    test('stressed context has low playfulness', () {
      final analysis = classifier.classify(ctx(
        trigger: ReactionTrigger.errorEvent,
      ));
      expect(analysis.playfulnessLevel, lessThan(0.2));
    });

    test('upbeat context has high playfulness', () {
      final analysis = classifier.classify(ctx(
        agentState: 'completed',
      ));
      expect(analysis.playfulnessLevel, greaterThan(0.3));
    });

    // High urgency reduces playfulness
    test('high urgency reduces playfulness', () {
      final analysis = classifier.classify(ctx(
        urgency: 0.8,
        trigger: ReactionTrigger.wakeEvent,
      ));
      expect(analysis.detectedSignals, contains('high_urgency_reduces_playfulness'));
    });

    // Confidence increases with more signals
    test('multiple signals increase confidence', () {
      final single = classifier.classify(ctx(
        trigger: ReactionTrigger.errorEvent,
      ));
      final multi = classifier.classify(ctx(
        trigger: ReactionTrigger.errorEvent,
        agentState: 'failed',
        userTone: UserTone.frustrated,
      ));
      expect(multi.confidence, greaterThan(single.confidence));
    });

    // Urgency classification
    test('urgency classification from context', () {
      final low = classifier.classify(ctx(urgency: 0.1));
      final high = classifier.classify(ctx(urgency: 0.9));
      expect(low.urgencyLevel, ReactionUrgencyClass.low);
      expect(high.urgencyLevel, ReactionUrgencyClass.critical);
    });
  });

  group('ReactionMoodClassifier.enrichContext', () {
    test('copies mood hint and playfulness into context', () {
      final classifier = const ReactionMoodClassifier();
      final context = ctx(
        trigger: ReactionTrigger.wakeEvent,
      );
      final analysis = classifier.classify(context);
      final enriched = classifier.enrichContext(context, analysis);

      expect(enriched.moodHint, analysis.mood);
      expect(enriched.playfulnessLevel, analysis.playfulnessLevel);
    });

    test('enriched context preserves other fields', () {
      final classifier = const ReactionMoodClassifier();
      final context = ctx(
        trigger: ReactionTrigger.voiceState,
        voiceState: 'listening',
      );
      final analysis = classifier.classify(context);
      final enriched = classifier.enrichContext(context, analysis);

      expect(enriched.trigger, context.trigger);
      expect(enriched.voiceState, context.voiceState);
    });
  });
}
