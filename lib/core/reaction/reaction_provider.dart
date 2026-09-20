/// Riverpod providers for the Reaction subsystem.
///
/// Follows the project pattern: dedicated provider file per subsystem
/// (cf. floating_aura_provider.dart, screen_capture_provider.dart).
///
/// Providers:
/// - [reactionCatalogProvider] — the reaction catalog (pre-populated)
/// - [reactionEngineProvider] — the StateNotifier engine
/// - [moodClassifierProvider] — mood classifier (Step 4)
/// - [keywordHintRegistryProvider] — keyword hint registry (Step 4)
/// - [variationEngineProvider] — variation engine (Step 4)
/// - [styleAwareSelectorProvider] — style-aware selector (Step 4)
///
/// Step 4 scope: providers are wired but NOT connected to any UI or
/// other subsystem providers. Integration is a future step.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reaction_catalog.dart';
import 'reaction_engine.dart';
import 'reaction_history.dart';
import 'reaction_selector.dart';
import 'reaction_random.dart';
import 'reaction_clock.dart';
import 'reaction_state.dart';
import 'reaction_sample_definitions.dart';
import 'reaction_mood_classifier.dart';
import 'reaction_keyword_hints.dart';
import 'reaction_variation_engine.dart';
import 'reaction_style_selector.dart';

/// Provider for the [ReactionCatalog] with sample definitions pre-registered.
///
/// In a future step, this will be populated from a config/data source.
/// For Step 2, we use the sample definitions for testing.
final reactionCatalogProvider = Provider<ReactionCatalog>((ref) {
  final catalog = ReactionCatalog();
  for (final reaction in sampleReactions) {
    catalog.register(reaction);
  }
  // Step 4: also register the style-variety samples.
  for (final reaction in step4SampleReactions) {
    catalog.register(reaction);
  }
  return catalog;
});

/// Provider for the [DefaultClock].
///
/// Can be overridden in tests with [FrozenClock].
final reactionClockProvider = Provider<Clock>((ref) {
  return const DefaultClock();
});

/// Provider for the [DefaultRandomSource].
///
/// Can be overridden in tests with [DeterministicRandomSource].
final reactionRandomSourceProvider = Provider<RandomSource>((ref) {
  return DefaultRandomSource();
});

/// Provider for the [ReactionHistory].
///
/// Depends on [reactionClockProvider] for timestamp generation.
final reactionHistoryProvider = Provider<ReactionHistory>((ref) {
  return ReactionHistory(
    clock: ref.watch(reactionClockProvider),
  );
});

/// Provider for the [ReactionSelector].
final reactionSelectorProvider = Provider<ReactionSelector>((ref) {
  return const ReactionSelector();
});

/// Provider for the [ReactionMoodClassifier] (Step 4).
final moodClassifierProvider = Provider<ReactionMoodClassifier>((ref) {
  return const ReactionMoodClassifier();
});

/// Provider for the [ReactionKeywordHintRegistry] (Step 4).
///
/// Pre-populated with default Kurdish Sorani and English hints.
final keywordHintRegistryProvider = Provider<ReactionKeywordHintRegistry>((ref) {
  final registry = ReactionKeywordHintRegistry();
  registry.registerAll(defaultCkbHints);
  registry.registerAll(defaultEnHints);
  return registry;
});

/// Provider for the [ReactionVariationEngine] (Step 4).
final variationEngineProvider = Provider<ReactionVariationEngine>((ref) {
  return ReactionVariationEngine();
});

/// Provider for the [StyleAwareSelector] (Step 4).
///
/// Wires together the base selector, mood classifier, variation engine,
/// and keyword hint registry.
final styleAwareSelectorProvider = Provider<StyleAwareSelector>((ref) {
  return StyleAwareSelector(
    baseSelector: ref.watch(reactionSelectorProvider),
    moodClassifier: ref.watch(moodClassifierProvider),
    variationEngine: ref.watch(variationEngineProvider),
    keywordRegistry: ref.watch(keywordHintRegistryProvider),
  );
});

/// Provider for the [ReactionEngine] StateNotifier.
///
/// Wires together catalog, selector, history, random, and clock.
/// Follows the [FloatingAuraStateNotifier] pattern.
///
/// Step 5: Uses [styleAwareSelectorProvider] directly for full
/// Step 4 pipeline (mood classification, keyword boosts, variation).
final reactionEngineProvider =
    StateNotifierProvider<ReactionEngine, ReactionState>((ref) {
  return ReactionEngine(
    catalog: ref.watch(reactionCatalogProvider),
    selector: ref.watch(styleAwareSelectorProvider),
    history: ref.watch(reactionHistoryProvider),
    randomSource: ref.watch(reactionRandomSourceProvider),
    clock: ref.watch(reactionClockProvider),
  );
});
