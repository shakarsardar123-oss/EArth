/// Style-aware reaction selector — extends [ReactionSelector] with
/// Step 4 intelligence: mood classification, visual style rotation,
/// keyword hints, and variation engine.
///
/// Pipeline stages:
///   1. Filter: narrow catalog entries to eligible (from [ReactionSelector])
///   2. Mood classify: analyze context → [ReactionMoodAnalysis]
///   3. Keyword boost: apply keyword hint boosts to matching reactions
///   4. Anti-repetition: penalize recently-fired reactions (from [ReactionSelector])
///   5. Variation: apply style rotation and diversity bonuses
///   6. Mood weight: adjust weights based on mood/tone compatibility
///   7. Weighted random: select one reaction
///
/// Returns a [StyleAwareSelection] with the chosen reaction and
/// analysis metadata for debugging/logging.
///
/// All operations are pure and synchronous — no side effects, no async.
/// State mutation (history recording) remains the engine's responsibility.
///
/// Step 4 scope: selection intelligence ONLY. No UI, no rendering.
library;

import 'reaction_model.dart';
import 'reaction_context.dart';
import 'reaction_catalog.dart';
import 'reaction_history.dart';
import 'reaction_random.dart';
import 'reaction_selector.dart';
import 'reaction_mood_classifier.dart';
import 'reaction_visual_style.dart';
import 'reaction_variation_engine.dart';
import 'reaction_keyword_hints.dart';

/// Result of style-aware selection — enriched with analysis metadata.
class StyleAwareSelection {
  const StyleAwareSelection._({
    this.reaction,
    this.moodAnalysis,
    this.variationResult,
    this.keywordBoosts = const [],
    this.reason,
  });

  /// The selected reaction, or null if nothing was eligible.
  final Reaction? reaction;

  /// Mood analysis that influenced this selection.
  final ReactionMoodAnalysis? moodAnalysis;

  /// Variation engine result (style rotation info).
  final VariationResult? variationResult;

  /// Keyword boosts applied during selection.
  final List<String> keywordBoosts;

  /// Why this result was produced (for logging / debugging).
  final String? reason;

  /// No eligible reaction was found.
  static const StyleAwareSelection none =
      StyleAwareSelection._(reason: 'no eligible reaction');

  /// A reaction was successfully selected.
  factory StyleAwareSelection.selected(
    Reaction reaction, {
    ReactionMoodAnalysis? moodAnalysis,
    VariationResult? variationResult,
    List<String> keywordBoosts = const [],
  }) =>
      StyleAwareSelection._(
        reaction: reaction,
        moodAnalysis: moodAnalysis,
        variationResult: variationResult,
        keywordBoosts: keywordBoosts,
        reason: 'selected',
      );

  /// Whether a reaction was selected.
  bool get hasReaction => reaction != null;

  @override
  String toString() =>
      hasReaction
          ? 'StyleAwareSelected(${reaction!.id}, mood: ${moodAnalysis?.mood}, '
              'style: ${variationResult?.recentStyle})'
          : 'None($reason)';
}

/// Internal weighted entry for style-aware selection.
class _StyleWeightedEntry {
  const _StyleWeightedEntry(this.reaction, this.weight, this.visualStyle);
  final Reaction reaction;
  final double weight;
  final ReactionVisualStyle visualStyle;
}

/// Style-aware selector — extends [ReactionSelector] with Step 4 intelligence.
///
/// Uses the base [ReactionSelector] for filtering and anti-repetition,
/// then adds mood classification, keyword boosts, and variation.
class StyleAwareSelector {
  StyleAwareSelector({
    ReactionSelector? baseSelector,
    ReactionMoodClassifier? moodClassifier,
    ReactionVariationEngine? variationEngine,
    this.keywordRegistry,
  })  : baseSelector = baseSelector ?? const ReactionSelector(),
        moodClassifier = moodClassifier ?? const ReactionMoodClassifier(),
        variationEngine = variationEngine ?? ReactionVariationEngine();

  /// Base selector for filtering and anti-repetition (Step 2 logic).
  final ReactionSelector baseSelector;

  /// Mood classifier for context analysis.
  final ReactionMoodClassifier moodClassifier;

  final ReactionVariationEngine variationEngine;

  /// Optional keyword hint registry for priority boosts.
  final ReactionKeywordHintRegistry? keywordRegistry;

  /// Execute the full style-aware selection pipeline.
  ///
  /// Parameters:
  /// - [catalog]: reaction catalog
  /// - [context]: current reaction context
  /// - [history]: recent reaction history
  /// - [random]: injectable random source
  /// - [detectedKeywords]: optional list of keywords detected from
  ///   the current interaction (for keyword boost stage)
  StyleAwareSelection select({
    required ReactionCatalog catalog,
    required ReactionContext context,
    required ReactionHistory history,
    required RandomSource random,
    List<String> detectedKeywords = const [],
  }) {
    // ── Stage 1: Filter eligible reactions (reuse base selector logic) ──
    final eligible = _filterEligible(catalog, context);
    if (eligible.isEmpty) {
      return StyleAwareSelection.none;
    }

    // ── Stage 2: Mood classification ──
    final moodAnalysis = moodClassifier.classify(context);

    // ── Stage 3: Compute base weights with anti-repetition ──
    final baseWeighted = _applyAntiRepetition(eligible, history, context);
    if (baseWeighted.isEmpty) {
      return StyleAwareSelection.none;
    }

    // ── Stage 4: Keyword boosts ──
    final keywordBoostList = <String>[];
    final keywordBoosts = _applyKeywordBoosts(
      baseWeighted,
      detectedKeywords,
      keywordBoostList,
    );

    // ── Stage 5: Mood weight adjustment ──
    final moodWeighted = _applyMoodWeights(keywordBoosts, moodAnalysis);

    // ── Stage 6: Variation (style rotation) ──
    // First, register styles with the variation engine.
    variationEngine.registerAllStyles(catalog.all);
    final variationResult = variationEngine.applyVariation(
      candidates: moodWeighted.map((e) => e.reaction).toList(),
      history: history,
      random: random,
      allReactionsForFallbackCheck: catalog.all,
    );

    // Merge variation weights with mood-adjusted weights.
    final finalEntries = _mergeVariationWeights(moodWeighted, variationResult);
    if (finalEntries.isEmpty) {
      return StyleAwareSelection.none;
    }

    // ── Stage 7: Weighted random selection ──
    final selected = _weightedSelect(finalEntries, random);
    if (selected == null) {
      return StyleAwareSelection.none;
    }

    return StyleAwareSelection.selected(
      selected,
      moodAnalysis: moodAnalysis,
      variationResult: variationResult,
      keywordBoosts: keywordBoostList,
    );
  }

  /// Stage 1: Filter catalog entries that match the context.
  /// Reuses the same logic as [ReactionSelector._filterEligible].
  List<Reaction> _filterEligible(
    ReactionCatalog catalog,
    ReactionContext context,
  ) {
    final candidates = catalog.getByTrigger(context.trigger);
    return candidates.where((r) => _isEligible(r, context)).toList();
  }

  /// Check a single reaction against context constraints.
  /// Mirrors [ReactionSelector._isEligible].
  bool _isEligible(Reaction reaction, ReactionContext context) {
    if (reaction.requiredAgentStates.isNotEmpty &&
        context.agentState != null &&
        !reaction.requiredAgentStates.contains(context.agentState)) {
      return false;
    }
    if (reaction.requiredVoiceStates.isNotEmpty &&
        context.voiceState != null &&
        !reaction.requiredVoiceStates.contains(context.voiceState)) {
      return false;
    }
    if (reaction.requiredIntentTypes.isNotEmpty &&
        context.intentActionType != null &&
        !reaction.requiredIntentTypes.contains(context.intentActionType)) {
      return false;
    }
    if (reaction.requiredConfidenceMin != null &&
        context.intentConfidence != null &&
        context.intentConfidence! < reaction.requiredConfidenceMin!) {
      return false;
    }
    return true;
  }

  /// Stage 3: Apply anti-repetition penalties (reuses base selector logic).
  List<_StyleWeightedEntry> _applyAntiRepetition(
    List<Reaction> eligible,
    ReactionHistory history,
    ReactionContext context,
  ) {
    final antiRep = baseSelector.antiRepetition;
    final result = <_StyleWeightedEntry>[];

    for (final reaction in eligible) {
      double weight = reaction.weight * reaction.effectivePriority;

      if (history.isInCooldown(reaction.id, reaction.cooldown)) {
        weight *= (1.0 - antiRep.cooldownPenalty);
      }

      final repeats = history.repeatCount(reaction.id);
      if (repeats > 0) {
        final penalty = repeats * antiRep.recentCountPenalty;
        weight *= (1.0 - penalty.clamp(0.0, 0.95));
      }

      if (weight > 0.001) {
        result.add(_StyleWeightedEntry(
          reaction,
          weight,
          defaultStyleForType(reaction.type),
        ));
      }
    }
    return result;
  }

  /// Stage 4: Apply keyword boosts from the hint registry.
  List<_StyleWeightedEntry> _applyKeywordBoosts(
    List<_StyleWeightedEntry> entries,
    List<String> detectedKeywords,
    List<String> outKeywordBoosts,
  ) {
    if (keywordRegistry == null || detectedKeywords.isEmpty) {
      return entries;
    }

    final result = <_StyleWeightedEntry>[];
    for (final entry in entries) {
      double boost = keywordRegistry!.computeBoost(
        detectedKeywords: detectedKeywords,
        reactionCategory: entry.reaction.category,
        reactionTags: entry.reaction.tags,
      );
      if (boost > 0) {
        outKeywordBoosts.add(
          '${entry.reaction.id}: +${boost.toStringAsFixed(2)}',
        );
      }
      result.add(_StyleWeightedEntry(
        entry.reaction,
        entry.weight + boost * entry.weight,
        entry.visualStyle,
      ));
    }
    return result;
  }

  /// Stage 5: Adjust weights based on mood/tone compatibility.
  ///
  /// Mood-tone alignment boosts reactions whose [Reaction.tone]
  /// matches the classified mood.
  List<_StyleWeightedEntry> _applyMoodWeights(
    List<_StyleWeightedEntry> entries,
    ReactionMoodAnalysis analysis,
  ) {
    final result = <_StyleWeightedEntry>[];

    for (final entry in entries) {
      double weight = entry.weight;
      final reaction = entry.reaction;

      // Mood-tone alignment bonus.
      final toneMatch = _moodToneAlignment(analysis.mood, reaction.tone);
      if (toneMatch > 0) {
        weight += toneMatch * 0.1 * weight;
      }

      // Playfulness alignment: humorous reactions get boosted in
      // high-playfulness contexts, penalized in low-playfulness.
      if (reaction.tone == ReactionTone.humorous) {
        final playfulness = analysis.playfulnessLevel;
        if (playfulness >= 0.6) {
          weight *= (1.0 + playfulness * 0.2);
        } else if (playfulness <= 0.2) {
          weight *= 0.5;
        }
      }

      // Technical tone gets boosted in focused mood.
      if (reaction.tone == ReactionTone.technical &&
          analysis.mood == ReactionMoodHint.focused) {
        weight *= 1.15;
      }

      result.add(_StyleWeightedEntry(
        reaction,
        weight,
        entry.visualStyle,
      ));
    }
    return result;
  }

  /// Compute alignment between mood and tone (0.0 = no alignment, 1.0 = full).
  double _moodToneAlignment(ReactionMoodHint mood, ReactionTone tone) {
    return switch ((mood, tone)) {
      (ReactionMoodHint.upbeat, ReactionTone.positive) => 1.0,
      (ReactionMoodHint.upbeat, ReactionTone.humorous) => 0.8,
      (ReactionMoodHint.stressed, ReactionTone.soothing) => 1.0,
      (ReactionMoodHint.stressed, ReactionTone.neutral) => 0.5,
      (ReactionMoodHint.focused, ReactionTone.technical) => 1.0,
      (ReactionMoodHint.focused, ReactionTone.neutral) => 0.5,
      (ReactionMoodHint.relaxed, ReactionTone.humorous) => 0.8,
      (ReactionMoodHint.relaxed, ReactionTone.positive) => 0.6,
      (ReactionMoodHint.curious, ReactionTone.neutral) => 0.5,
      (ReactionMoodHint.curious, ReactionTone.technical) => 0.7,
      _ => 0.0,
    };
  }

  /// Stage 6: Merge variation engine weights with mood-adjusted weights.
  List<_StyleWeightedEntry> _mergeVariationWeights(
    List<_StyleWeightedEntry> moodWeighted,
    VariationResult variationResult,
  ) {
    final variedMap = <String, double>{};
    for (final ve in variationResult.entries) {
      variedMap[ve.reaction.id] = ve.variationWeight;
    }

    final result = <_StyleWeightedEntry>[];
    for (final entry in moodWeighted) {
      // Use variation weight if available, otherwise use mood weight.
      final weight = variedMap[entry.reaction.id] ?? entry.weight;
      if (weight > 0.001) {
        result.add(_StyleWeightedEntry(
          entry.reaction,
          weight,
          entry.visualStyle,
        ));
      }
    }
    return result;
  }

  /// Stage 7: Weighted random selection.
  Reaction? _weightedSelect(
    List<_StyleWeightedEntry> entries,
    RandomSource random,
  ) {
    if (entries.isEmpty) return null;

    final totalWeight = entries.fold<double>(0.0, (sum, e) => sum + e.weight);
    if (totalWeight <= 0) return null;

    double roll = random.nextDouble() * totalWeight;
    double cumulative = 0.0;

    for (final entry in entries) {
      cumulative += entry.weight;
      if (roll < cumulative) {
        return entry.reaction;
      }
    }
    return entries.last.reaction;
  }
}
