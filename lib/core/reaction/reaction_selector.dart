/// Reaction selection pipeline — the core algorithm of the system.
///
/// Pipeline stages:
///   1. Filter: narrow catalog entries to those eligible for [ReactionContext]
///   2. Anti-repetition: penalize recently-fired reactions
///   3. Weighted random: select one reaction from the remaining pool
///
/// Returns a [ReactionSelection] containing the chosen reaction, or
/// [ReactionSelection.none] if no eligible reaction exists.
///
/// All operations are pure and synchronous — no side effects, no async.
/// State mutation (history recording) is the engine's responsibility.
library;

import 'reaction_model.dart';
import 'reaction_context.dart';
import 'reaction_catalog.dart';
import 'reaction_history.dart';
import 'reaction_random.dart';

/// Result of a selection pass.
class ReactionSelection {
  const ReactionSelection._({this.reaction, this.reason});

  /// The selected reaction, or null if nothing was eligible.
  final Reaction? reaction;

  /// Why this result was produced (for logging / debugging).
  final String? reason;

  /// No eligible reaction was found.
  static const ReactionSelection none =
      ReactionSelection._(reason: 'no eligible reaction');

  /// A reaction was successfully selected.
  factory ReactionSelection.selected(Reaction reaction) =>
      ReactionSelection._(reaction: reaction, reason: 'selected');

  /// Whether a reaction was selected.
  bool get hasReaction => reaction != null;

  @override
  String toString() =>
      hasReaction ? 'Selected(${reaction!.id})' : 'None($reason)';
}

/// Weighted entry used during selection.
class _WeightedEntry {
  const _WeightedEntry(this.reaction, this.weight);
  final Reaction reaction;
  final double weight;
}

/// Anti-repetition penalty configuration.
class AntiRepetitionConfig {
  const AntiRepetitionConfig({
    this.recentCountPenalty = 0.3,
    this.recentCountDecay = 0.2,
    this.cooldownPenalty = 0.85,
  });

  /// Fraction of weight to subtract per recent occurrence in the buffer.
  /// e.g. if a reaction appears 2× recently, penalty = 2 × 0.3 = 0.6 off weight.
  final double recentCountPenalty;

  /// Decay factor per position from the most recent entry.
  /// Oldest entries contribute less to the penalty.
  final double recentCountDecay;

  /// Fraction of weight to subtract if the reaction is within its cooldown.
  final double cooldownPenalty;
}

/// Pure-function selection pipeline.
///
/// Stateless — receives catalog + history as parameters and returns
/// a [ReactionSelection]. The [ReactionEngine] owns the instances and
/// handles history recording after a successful selection.
class ReactionSelector {
  const ReactionSelector({
    this.antiRepetition = const AntiRepetitionConfig(),
  });

  final AntiRepetitionConfig antiRepetition;

  /// Execute the full selection pipeline.
  ReactionSelection select({
    required ReactionCatalog catalog,
    required ReactionContext context,
    required ReactionHistory history,
    required RandomSource random,
  }) {
    // Stage 1: Filter eligible reactions from catalog.
    final eligible = _filterEligible(catalog, context);
    if (eligible.isEmpty) {
      return ReactionSelection.none;
    }

    // Stage 2: Apply anti-repetition penalties.
    final weighted = _applyAntiRepetition(eligible, history, context);
    if (weighted.isEmpty) {
      return ReactionSelection.none;
    }

    // Stage 3: Weighted random selection.
    final selected = _weightedSelect(weighted, random);
    if (selected == null) {
      return ReactionSelection.none;
    }

    return ReactionSelection.selected(selected);
  }

  /// Stage 1: Filter catalog entries that match the context.
  List<Reaction> _filterEligible(
    ReactionCatalog catalog,
    ReactionContext context,
  ) {
    final candidates = catalog.getByTrigger(context.trigger);
    return candidates.where((r) => _isEligible(r, context)).toList();
  }

  /// Check a single reaction against context constraints.
  bool _isEligible(Reaction reaction, ReactionContext context) {
    // Required agent states — empty means any state is fine.
    if (reaction.requiredAgentStates.isNotEmpty &&
        context.agentState != null &&
        !reaction.requiredAgentStates.contains(context.agentState)) {
      return false;
    }

    // Required voice states — empty means any state is fine.
    if (reaction.requiredVoiceStates.isNotEmpty &&
        context.voiceState != null &&
        !reaction.requiredVoiceStates.contains(context.voiceState)) {
      return false;
    }

    // Required intent types — empty means any type is fine.
    if (reaction.requiredIntentTypes.isNotEmpty &&
        context.intentActionType != null &&
        !reaction.requiredIntentTypes.contains(context.intentActionType)) {
      return false;
    }

    // Minimum confidence.
    if (reaction.requiredConfidenceMin != null &&
        context.intentConfidence != null &&
        context.intentConfidence! < reaction.requiredConfidenceMin!) {
      return false;
    }

    return true;
  }

  /// Stage 2: Compute effective weight with anti-repetition penalties.
  List<_WeightedEntry> _applyAntiRepetition(
    List<Reaction> eligible,
    ReactionHistory history,
    ReactionContext context,
  ) {
    final result = <_WeightedEntry>[];

    for (final reaction in eligible) {
      double weight = reaction.weight * reaction.effectivePriority;

      // Cooldown penalty — large penalty if still within cooldown window.
      if (history.isInCooldown(reaction.id, reaction.cooldown)) {
        weight *= (1.0 - antiRepetition.cooldownPenalty);
      }

      // Recent-count penalty — weight drops for each recent occurrence.
      final repeats = history.repeatCount(reaction.id);
      if (repeats > 0) {
        final penalty =
            repeats * antiRepetition.recentCountPenalty;
        weight *= (1.0 - penalty.clamp(0.0, 0.95));
      }

      // Only include entries with positive weight.
      if (weight > 0.001) {
        result.add(_WeightedEntry(reaction, weight));
      }
    }

    return result;
  }

  /// Stage 3: Weighted random selection from the candidate list.
  Reaction? _weightedSelect(
    List<_WeightedEntry> entries,
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

    // Fallback: floating-point rounding — return last entry.
    return entries.last.reaction;
  }
}
