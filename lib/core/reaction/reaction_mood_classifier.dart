/// Deterministic mood classifier for the AURA Dynamic Reaction System.
///
/// Consumes a [ReactionContext] and produces a [ReactionMoodAnalysis]
/// containing mood, urgency classification, playfulness level, confidence,
/// and detected signals. No ML, no network, no side effects.
///
/// The classifier uses rule-based heuristics derived from context fields:
/// - [ReactionTrigger] type (event vs state change)
/// - [ReactionContext.urgency] level
/// - [ReactionContext.userTone]
/// - [ReactionContext.agentState]
/// - [ReactionContext.voiceState]
/// - [ReactionContext.intentConfidence]
///
/// Step 4 scope: classification ONLY. No UI, no rendering.
library;

import 'reaction_context.dart';
import 'reaction_trigger.dart';
import '../../core/errors/result.dart';

/// Result of mood classification — immutable analysis snapshot.
class ReactionMoodAnalysis {
  const ReactionMoodAnalysis({
    required this.mood,
    required this.urgencyLevel,
    required this.playfulnessLevel,
    required this.confidence,
    required this.detectedSignals,
  });

  /// Classified mood hint.
  final ReactionMoodHint mood;

  /// Classified urgency level (low / normal / high / critical).
  final ReactionUrgencyClass urgencyLevel;

  /// Computed playfulness level (0.0–1.0).
  final double playfulnessLevel;

  /// Confidence in this classification (0.0–1.0).
  /// Higher = more signals agree, lower = ambiguous context.
  final double confidence;

  /// Human-readable list of signals that influenced the classification.
  final List<String> detectedSignals;

  /// Default / unknown analysis.
  static const ReactionMoodAnalysis unknown = ReactionMoodAnalysis(
    mood: ReactionMoodHint.none,
    urgencyLevel: ReactionUrgencyClass.normal,
    playfulnessLevel: 0.5,
    confidence: 0.0,
    detectedSignals: [],
  );

  @override
  bool operator ==(Object other) =>
      other is ReactionMoodAnalysis &&
      other.mood == mood &&
      other.urgencyLevel == urgencyLevel &&
      other.playfulnessLevel == playfulnessLevel &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(mood, urgencyLevel, playfulnessLevel, confidence);

  @override
  String toString() =>
      'ReactionMoodAnalysis(mood: $mood, urgency: $urgencyLevel, '
      'playfulness: ${playfulnessLevel.toStringAsFixed(2)}, '
      'confidence: ${confidence.toStringAsFixed(2)}, '
      'signals: $detectedSignals)';
}

/// Urgency classification from the mood classifier.
///
/// Maps the continuous [ReactionContext.urgency] (0.0–1.0) to discrete
/// buckets for use by the style-aware selector.
enum ReactionUrgencyClass {
  /// urgency 0.0–0.25: informational, no immediate action.
  low,

  /// urgency 0.25–0.50: standard priority.
  normal,

  /// urgency 0.50–0.75: time-sensitive.
  high,

  /// urgency 0.75–1.0: critical / security.
  critical;

  /// Classify from a continuous urgency value (0.0–1.0).
  static ReactionUrgencyClass fromValue(double urgency) {
    if (urgency >= 0.75) return ReactionUrgencyClass.critical;
    if (urgency >= 0.50) return ReactionUrgencyClass.high;
    if (urgency >= 0.25) return ReactionUrgencyClass.normal;
    return ReactionUrgencyClass.low;
  }

  /// Numeric weight for selection priority.
  double get weight => switch (this) {
        ReactionUrgencyClass.low => 0.25,
        ReactionUrgencyClass.normal => 0.5,
        ReactionUrgencyClass.high => 0.75,
        ReactionUrgencyClass.critical => 1.0,
      };
}

/// Deterministic mood classifier — pure function, no side effects.
///
/// Usage:
/// ```dart
/// final classifier = ReactionMoodClassifier();
/// final analysis = classifier.classify(context);
/// // Use analysis.mood, analysis.playfulnessLevel, etc.
/// ```
class ReactionMoodClassifier {
  const ReactionMoodClassifier();

  /// Classify a [ReactionContext] into a [ReactionMoodAnalysis].
  ///
  /// Rules (in priority order — first match wins for mood):
  /// 1. Error trigger + error states → stressed
  /// 2. Failed agent state → stressed
  /// 3. Frustrated user tone → stressed
  /// 4. Completed agent state → upbeat
  /// 5. Wake event → upbeat
  /// 6. Happy user tone → upbeat
  /// 7. Executing / processing agent → focused
  /// 8. Idle timeout + idle voice → relaxed
  /// 9. Low confidence / confused tone → curious
  /// 10. Default → none
  ReactionMoodAnalysis classify(ReactionContext context) {
    final signals = <String>[];
    ReactionMoodHint mood = ReactionMoodHint.none;
    double playfulness = 0.5;
    int signalCount = 0;

    // ── Rule 1: Error trigger / error states → stressed ──
    if (context.trigger == ReactionTrigger.errorEvent ||
        context.isError) {
      mood = ReactionMoodHint.stressed;
      playfulness = 0.1;
      signals.add('error_state');
      signalCount++;
    }

    // ── Rule 2: Failed agent state → stressed ──
    if (context.agentState == 'failed') {
      mood = ReactionMoodHint.stressed;
      playfulness = 0.05;
      signals.add('agent_failed');
      signalCount++;
    }

    // ── Rule 3: Frustrated user tone → stressed ──
    if (context.userTone == UserTone.frustrated) {
      mood = ReactionMoodHint.stressed;
      playfulness = 0.1;
      signals.add('frustrated_tone');
      signalCount++;
    }

    // ── Rule 4: Completed agent state → upbeat ──
    if (context.agentState == 'completed' &&
        mood != ReactionMoodHint.stressed) {
      mood = ReactionMoodHint.upbeat;
      playfulness = 0.7;
      signals.add('agent_completed');
      signalCount++;
    }

    // ── Rule 5: Wake event → upbeat ──
    if (context.trigger == ReactionTrigger.wakeEvent &&
        mood != ReactionMoodHint.stressed) {
      mood = ReactionMoodHint.upbeat;
      playfulness = 0.8;
      signals.add('wake_event');
      signalCount++;
    }

    // ── Rule 6: Happy user tone → upbeat ──
    if (context.userTone == UserTone.happy &&
        mood != ReactionMoodHint.stressed) {
      mood = ReactionMoodHint.upbeat;
      playfulness = 0.8;
      signals.add('happy_tone');
      signalCount++;
    }

    // ── Rule 7: Executing / processing agent → focused ──
    if ((context.agentState == 'executing' ||
        context.agentState == 'understanding' ||
        context.agentState == 'planning' ||
        context.agentState == 'validating') &&
        mood == ReactionMoodHint.none) {
      mood = ReactionMoodHint.focused;
      playfulness = 0.3;
      signals.add('agent_processing');
      signalCount++;
    }

    // ── Rule 8: Idle timeout + idle voice → relaxed ──
    if (context.trigger == ReactionTrigger.idleTimeout &&
        mood == ReactionMoodHint.none) {
      mood = ReactionMoodHint.relaxed;
      playfulness = 0.7;
      signals.add('idle_timeout');
      signalCount++;
    }

    // ── Rule 9: Low confidence / confused tone → curious ──
    if ((context.intentConfidence != null &&
        context.intentConfidence! < 0.4) ||
        context.userTone == UserTone.confused) {
      if (mood == ReactionMoodHint.none) {
        mood = ReactionMoodHint.curious;
      }
      playfulness = 0.4;
      signals.add('low_confidence_or_confused');
      signalCount++;
    }

    // ── Urgency classification ──
    final urgencyLevel = ReactionUrgencyClass.fromValue(context.urgency);

    // ── Playfulness adjustment based on urgency ──
    // High urgency reduces playfulness.
    if (urgencyLevel == ReactionUrgencyClass.high ||
        urgencyLevel == ReactionUrgencyClass.critical) {
      playfulness = playfulness * 0.5;
      signals.add('high_urgency_reduces_playfulness');
    }

    // ── Confidence calculation ──
    // More signals = higher confidence in the classification.
    final confidence = signalCount >= 3
        ? 0.9
        : signalCount == 2
            ? 0.7
            : signalCount == 1
                ? 0.5
                : 0.2;

    return ReactionMoodAnalysis(
      mood: mood,
      urgencyLevel: urgencyLevel,
      playfulnessLevel: playfulness.clamp(0.0, 1.0),
      confidence: confidence,
      detectedSignals: signals,
    );
  }

  /// Build an enriched [ReactionContext] from the original context
  /// and the mood analysis result.
  ///
  /// This is a convenience method that copies the context with
  /// [moodHint] and [playfulnessLevel] fields set from the analysis.
  ReactionContext enrichContext(
    ReactionContext context,
    ReactionMoodAnalysis analysis,
  ) {
    return context.copyWith(
      moodHint: analysis.mood,
      playfulnessLevel: analysis.playfulnessLevel,
    );
  }
}
