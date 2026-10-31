/// Variation engine for the AURA Dynamic Reaction System.
///
/// Provides anti-repetition (extending [ReactionHistory]) and visual
/// style rotation to prevent visual monotony. Uses injectable
/// [RandomSource] for deterministic testing.
///
/// The variation engine is consumed by the style-aware selector
/// (Step 4 extended [ReactionSelector]) — it does NOT dispatch
/// reactions or control any UI.
///
/// Step 4 scope: selection intelligence ONLY. No rendering.
library;

import 'reaction_history.dart';
import 'reaction_visual_style.dart';
import 'reaction_random.dart';
import 'reaction_model.dart';
import 'reaction_type.dart';

/// Configuration for the variation engine.
class VariationConfig {
  const VariationConfig({
    this.styleRotationWeight = 0.3,
    this.maxSameStyleStreak = 3,
    this.styleDiversityBonus = 0.15,
    this.stylePenaltyWeight = 0.25,
    this.recentStyleLookback = 5,
  });

  /// How much weight the style rotation signal contributes (0.0–1.0).
  final double styleRotationWeight;

  /// Maximum consecutive reactions with the same visual style before
  /// a rotation penalty is applied.
  final int maxSameStyleStreak;

  /// Bonus weight added to reactions whose style differs from recent ones.
  final double styleDiversityBonus;

  /// Penalty applied per streak count beyond [maxSameStyleStreak].
  final double stylePenaltyWeight;

  /// How many recent history entries to examine for style streak detection.
  final int recentStyleLookback;
}

/// Result of variation analysis on a set of candidate reactions.
class VariationResult {
  const VariationResult({
    required this.entries,
    required this.recentStyleStreak,
    required this.recentStyle,
  });

  /// Weighted reaction entries after variation adjustments.
  final List<VariedEntry> entries;

  /// How many consecutive reactions had the same visual style.
  final int recentStyleStreak;

  /// The most recent visual style (null if no history).
  final ReactionVisualStyle? recentStyle;

  /// Whether any entries survived the variation filter.
  bool get hasCandidates => entries.isNotEmpty;
}

/// A reaction with its variation-adjusted weight.
class VariedEntry {
  const VariedEntry({
    required this.reaction,
    required this.baseWeight,
    required this.variationWeight,
    required this.visualStyle,
    required this.styleAdjustment,
  });

  /// The reaction definition.
  final Reaction reaction;

  /// Weight before variation adjustments.
  final double baseWeight;

  /// Weight after variation adjustments (used for final selection).
  final double variationWeight;

  /// The visual style of this reaction.
  final ReactionVisualStyle visualStyle;

  /// Description of the style adjustment applied (for debugging).
  final String styleAdjustment;

  @override
  String toString() =>
      'VariedEntry(${reaction.id}, base: ${baseWeight.toStringAsFixed(3)}, '
      'varied: ${variationWeight.toStringAsFixed(3)}, style: $visualStyle, '
      'adjust: $styleAdjustment)';
}

/// Pure-function variation engine — no side effects.
///
/// Consumes candidate reactions, history, and config to produce
/// variation-adjusted weights. The style-aware selector then uses
/// these weights for final weighted random selection.
class ReactionVariationEngine {
  ReactionVariationEngine({
    this.config = const VariationConfig(),
  });

  final VariationConfig config;

  /// Apply variation adjustments to candidate reactions.
  ///
  /// This extends the base anti-repetition from [ReactionSelector] with:
  /// 1. Style streak detection — penalize reactions whose style matches
  ///    a recent streak.
  /// 2. Style diversity bonus — boost reactions whose style differs
  ///    from the most recent reaction's style.
  /// 3. Graceful fallback — if all reactions share the same style,
  ///    no penalty is applied (can't rotate to something different).
  VariationResult applyVariation({
    required List<Reaction> candidates,
    required ReactionHistory history,
    required RandomSource random,
    List<Reaction>? allReactionsForFallbackCheck,
  }) {
    // ── Step 1: Detect recent style streak ──
    final recentStyles = _recentStyles(history);
    final recentStyle = recentStyles.isNotEmpty ? recentStyles.last : null;
    final streak = _styleStreak(recentStyles);

    // ── Step 2: Determine available styles ──
    final candidateStyles = candidates
        .map((r) => _styleForReaction(r))
        .toSet()
        .toList();
    final canRotate = candidateStyles.length > 1;

    // ── Step 3: Apply variation to each candidate ──
    final entries = <VariedEntry>[];
    for (final reaction in candidates) {
      final baseWeight = reaction.weight * reaction.effectivePriority;
      final style = _styleForReaction(reaction);
      double variedWeight = baseWeight;
      String adjustment = 'none';

      if (canRotate && recentStyle != null) {
        // Diversity bonus: different style from recent → boost.
        if (style != recentStyle) {
          variedWeight += config.styleDiversityBonus * baseWeight;
          adjustment = 'diversity_bonus';
        }

        // Streak penalty: same style as streak → penalize.
        if (style == recentStyle && streak >= config.maxSameStyleStreak) {
          final penaltyCount = streak - config.maxSameStyleStreak + 1;
          final penalty = penaltyCount * config.stylePenaltyWeight;
          variedWeight *= (1.0 - penalty.clamp(0.0, 0.9));
          adjustment = 'streak_penalty(${penaltyCount}x)';
        }
      } else if (!canRotate && recentStyle != null && streak >= config.maxSameStyleStreak) {
        // Graceful fallback: all candidates share the same style,
        // so we can't rotate. Apply a mild shuffle instead of penalty.
        adjustment = 'no_rotation_available';
      }

      // Only include entries with positive weight.
      if (variedWeight > 0.001) {
        entries.add(VariedEntry(
          reaction: reaction,
          baseWeight: baseWeight,
          variationWeight: variedWeight,
          visualStyle: style,
          styleAdjustment: adjustment,
        ));
      }
    }

    return VariationResult(
      entries: entries,
      recentStyleStreak: streak,
      recentStyle: recentStyle,
    );
  }

  /// Get the recent visual styles from history.
  List<ReactionVisualStyle> _recentStyles(ReactionHistory history) {
    final recent = history.recent(n: config.recentStyleLookback);
    return recent
        .map((e) => _styleForReactionId(e.reactionId))
        .whereType<ReactionVisualStyle>()
        .toList();
  }

  /// Count how many consecutive entries at the end share the same style.
  int _styleStreak(List<ReactionVisualStyle> styles) {
    if (styles.isEmpty) return 0;
    final last = styles.last;
    int count = 0;
    for (var i = styles.length - 1; i >= 0; i--) {
      if (styles[i] == last) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  /// Determine the visual style for a reaction.
  ///
  /// Priority:
  /// 1. Explicit [reaction.visualStyle] (Step 4 field)
  /// 2. Payload key 'visualStyle' (legacy string)
  /// 3. Derived from [ReactionPresentationType] via [defaultStyleForType]
  ReactionVisualStyle _styleForReaction(Reaction reaction) {
    // Check explicit visualStyle field (Step 4).
    if (reaction.visualStyle != null) {
      return reaction.visualStyle!;
    }
    // Check payload for legacy visual style.
    final explicitStyle = reaction.payload?['visualStyle'];
    if (explicitStyle is String) {
      return ReactionVisualStyle.values.firstWhere(
        (v) => v.label == explicitStyle,
        orElse: () => defaultStyleForType(reaction.type),
      );
    }
    return defaultStyleForType(reaction.type);
  }

  /// Resolve a reactionId to its visual style via the catalog.
  ///
  /// Returns null if the reaction is not in the catalog (history
  /// may reference reactions that were unregistered).
  ReactionVisualStyle? _styleForReactionId(String reactionId) {
    // We don't have direct catalog access here. Instead, we maintain
    // a lightweight id→style cache populated during applyVariation.
    // For history lookups, we use a simplified approach.
    return _idStyleCache[reactionId];
  }

  /// Lightweight id→style cache for history resolution.
  /// Populated during applyVariation from the candidate list.
  final Map<String, ReactionVisualStyle> _idStyleCache = {};

  /// Register a reaction id → style mapping for history resolution.
  ///
  /// Call this when a reaction is registered in the catalog so that
  /// the variation engine can resolve styles for historical entries.
  void registerStyle(String reactionId, ReactionVisualStyle style) {
    _idStyleCache[reactionId] = style;
  }

  /// Register all reactions from a list with their default styles.
  void registerAllStyles(List<Reaction> reactions) {
    for (final reaction in reactions) {
      _idStyleCache[reaction.id] = _styleForReaction(reaction);
    }
  }

  /// Clear the style cache.
  void clearStyleCache() => _idStyleCache.clear();
}
