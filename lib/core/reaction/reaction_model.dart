/// Immutable data model for a single reaction definition.
///
/// A [Reaction] is a declarative rule: "when trigger X fires under
/// condition Y, show presentation Z with priority P." The reaction
/// engine evaluates all eligible reactions and selects one via
/// weighted random selection.
///
/// Uses const constructor and @immutable pattern consistent with
/// existing project models (ToolDefinition, FloatingAuraState, etc.).
library;

import 'package:meta/meta.dart' show immutable;

import 'reaction_type.dart';
import 'reaction_trigger.dart';
import 'reaction_visual_style.dart';

/// User-perceived urgency level — affects selection priority.
enum ReactionUrgency {
  /// Informational, no immediate action needed.
  low,

  /// Standard priority.
  normal,

  /// Time-sensitive (e.g. error, confirmation needed).
  high,

  /// Critical (e.g. security alert, permission required now).
  critical;

  /// Numeric value for comparison and weighting.
  double get value => switch (this) {
        ReactionUrgency.low => 0.25,
        ReactionUrgency.normal => 0.5,
        ReactionUrgency.high => 0.75,
        ReactionUrgency.critical => 1.0,
      };
}

/// Perceived user tone that this reaction is designed for.
enum ReactionTone {
  /// Neutral / informational.
  neutral,

  /// Encouraging / positive.
  positive,

  /// Humorous / lighthearted.
  humorous,

  /// Soothing / calming (e.g. after an error).
  soothing,

  /// Technical / precise (e.g. terminal output).
  technical;
}

/// An immutable reaction definition.
///
/// In Step 2 this is a pure data model — no behavior, no side effects.
/// The [ReactionSelector] reads these fields to determine eligibility
/// and weight for selection.
@immutable
class Reaction {
  const Reaction({
    required this.id,
    required this.type,
    required this.trigger,
    required this.priority,
    this.weight = 1.0,
    this.cooldown = const Duration(seconds: 30),
    this.l10nKey,
    this.urgency = ReactionUrgency.normal,
    this.tone = ReactionTone.neutral,
    this.requiredAgentStates = const [],
    this.requiredVoiceStates = const [],
    this.requiredIntentTypes = const [],
    this.requiredConfidenceMin,
    this.payload,
    this.category = 'general',
    this.tags = const [],
    this.visualStyle,
  });

  /// Unique identifier for this reaction (e.g. 'listening_emoji').
  final String id;

  /// How this reaction should be visually presented.
  final ReactionPresentationType type;

  /// The trigger source this reaction responds to.
  final ReactionTrigger trigger;

  /// Base priority (0.0–1.0). Higher = more likely to be selected.
  final double priority;

  /// Weight multiplier for random selection (default 1.0).
  final double weight;

  /// Minimum cooldown between firings of this same reaction.
  final Duration cooldown;

  /// Localization key for text content (ARB or hand-written S class).
  final String? l10nKey;

  /// Urgency level — affects selection priority.
  final ReactionUrgency urgency;

  /// Target tone this reaction is designed for.
  final ReactionTone tone;

  /// Agent states that must be active for this reaction to be eligible.
  /// Empty = eligible for any agent state (trigger still applies).
  final List<String> requiredAgentStates;

  /// Voice states that must be active for this reaction to be eligible.
  /// Empty = eligible for any voice state.
  final List<String> requiredVoiceStates;

  /// Intent action types that must match for this reaction to be eligible.
  /// Empty = eligible for any intent type.
  final List<String> requiredIntentTypes;

  /// Minimum confidence score required (0.0–1.0). null = any confidence.
  final double? requiredConfidenceMin;

  /// Type-specific payload data (e.g. emoji char, animation key, text).
  final Map<String, dynamic>? payload;

  /// Category for grouping (e.g. 'voice', 'agent', 'idle', 'error').
  final String category;

  /// Tags for filtering (e.g. 'personality', 'feedback', 'idle_hint').
  final List<String> tags;

  /// Visual style category (Step 4).
  ///
  /// If null, the style-aware selector derives the style from
  /// [type] via [defaultStyleForType]. Setting this explicitly
  /// overrides the derived style for rotation / variation.
  ///
  /// Backward compatible: all Step 2 definitions have this as null.
  final ReactionVisualStyle? visualStyle;

  /// Effective priority = base priority × urgency value.
  double get effectivePriority => priority * urgency.value;

  /// Whether this reaction can be rendered on the native overlay.
  bool get isNativeRenderable => type.isNativeRenderable;

  Reaction copyWith({
    String? id,
    ReactionPresentationType? type,
    ReactionTrigger? trigger,
    double? priority,
    double? weight,
    Duration? cooldown,
    String? l10nKey,
    ReactionUrgency? urgency,
    ReactionTone? tone,
    List<String>? requiredAgentStates,
    List<String>? requiredVoiceStates,
    List<String>? requiredIntentTypes,
    double? requiredConfidenceMin,
    Map<String, dynamic>? payload,
    String? category,
    List<String>? tags,
    ReactionVisualStyle? visualStyle,
    bool clearVisualStyle = false,
  }) {
    return Reaction(
      id: id ?? this.id,
      type: type ?? this.type,
      trigger: trigger ?? this.trigger,
      priority: priority ?? this.priority,
      weight: weight ?? this.weight,
      cooldown: cooldown ?? this.cooldown,
      l10nKey: l10nKey ?? this.l10nKey,
      urgency: urgency ?? this.urgency,
      tone: tone ?? this.tone,
      requiredAgentStates: requiredAgentStates ?? this.requiredAgentStates,
      requiredVoiceStates: requiredVoiceStates ?? this.requiredVoiceStates,
      requiredIntentTypes: requiredIntentTypes ?? this.requiredIntentTypes,
      requiredConfidenceMin:
          requiredConfidenceMin ?? this.requiredConfidenceMin,
      payload: payload ?? this.payload,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      visualStyle: clearVisualStyle ? null : (visualStyle ?? this.visualStyle),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Reaction &&
        other.id == id &&
        other.type == type &&
        other.trigger == trigger &&
        other.priority == priority &&
        other.weight == weight &&
        other.cooldown == cooldown &&
        other.l10nKey == l10nKey &&
        other.urgency == urgency &&
        other.tone == tone &&
        other.category == category &&
        other.visualStyle == visualStyle;
  }

  @override
  int get hashCode => Object.hash(
        id,
        type,
        trigger,
        priority,
        weight,
        cooldown,
        l10nKey,
        urgency,
        tone,
        category,
        visualStyle,
      );

  @override
  String toString() =>
      'Reaction($id, trigger: $trigger, type: $type, priority: $priority)';
}
