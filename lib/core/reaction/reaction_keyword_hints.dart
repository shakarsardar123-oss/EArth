/// Lightweight keyword hint layer for the AURA Dynamic Reaction System.
///
/// Provides optional, extensible keyword hints in Kurdish Sorani (ckb)
/// and English (en) that can influence reaction selection. Keywords are
/// matched against context signals (intent action type, agent state, etc.)
/// to boost the priority of reactions whose tags/categories align.
///
/// This is a **hint system only** — it never overrides safety, blocks
/// reactions, or controls any tool/UI. Presentation intelligence ONLY.
///
/// Step 4 scope: classification + mapping. No UI rendering.
library;

/// A single keyword hint entry.
///
/// Maps a keyword (in any language) to a [category] and optional
/// [tags] that should be boosted when this keyword is detected.
class ReactionKeywordHint {
  const ReactionKeywordHint({
    required this.keyword,
    required this.language,
    required this.category,
    this.tags = const [],
    this.boost = 0.1,
  });

  /// The keyword string (e.g. 'یارمەتی', 'help').
  final String keyword;

  /// Language code (e.g. 'ckb' for Kurdish Sorani, 'en' for English).
  final String language;

  /// Category to boost when this keyword is detected.
  final String category;

  /// Tags to boost when this keyword is detected.
  final List<String> tags;

  /// Priority boost amount (0.0–1.0, default 0.1).
  /// This is additive to the reaction's effective priority.
  final double boost;

  @override
  bool operator ==(Object other) =>
      other is ReactionKeywordHint &&
      other.keyword == keyword &&
      other.language == language &&
      other.category == category;

  @override
  int get hashCode => Object.hash(keyword, language, category);

  @override
  String toString() =>
      'ReactionKeywordHint($keyword [$language] → $category, boost: $boost)';
}

/// Registry of keyword hints — extensible, lightweight.
///
/// Usage:
/// ```dart
/// final registry = ReactionKeywordHintRegistry();
/// registry.register(ReactionKeywordHint(
///   keyword: 'یارمەتی', language: 'ckb', category: 'agent',
///   tags: ['feedback'], boost: 0.15,
/// ));
/// ```
class ReactionKeywordHintRegistry {
  final List<ReactionKeywordHint> _hints = [];

  /// Register a keyword hint.
  void register(ReactionKeywordHint hint) {
    _hints.add(hint);
  }

  /// Register multiple hints at once.
  void registerAll(List<ReactionKeywordHint> hints) {
    _hints.addAll(hints);
  }

  /// All registered hints.
  List<ReactionKeywordHint> get all => List.unmodifiable(_hints);

  /// Number of registered hints.
  int get count => _hints.length;

  /// Find hints matching a keyword (case-insensitive).
  List<ReactionKeywordHint> findByKeyword(String keyword) {
    final lower = keyword.toLowerCase();
    return _hints.where((h) => h.keyword.toLowerCase() == lower).toList();
  }

  /// Find hints matching a language code.
  List<ReactionKeywordHint> findByLanguage(String language) {
    return _hints.where((h) => h.language == language).toList();
  }

  /// Find hints matching a category.
  List<ReactionKeywordHint> findByCategory(String category) {
    return _hints.where((h) => h.category == category).toList();
  }

  /// Compute the total priority boost for a given set of detected keywords
  /// against a reaction's category and tags.
  ///
  /// Returns the sum of all matching hint boosts (capped at 1.0).
  double computeBoost({
    required List<String> detectedKeywords,
    required String reactionCategory,
    required List<String> reactionTags,
  }) {
    double total = 0.0;
    for (final keyword in detectedKeywords) {
      final matches = findByKeyword(keyword);
      for (final match in matches) {
        if (match.category == reactionCategory ||
            match.tags.any((t) => reactionTags.contains(t))) {
          total += match.boost;
        }
      }
    }
    return total.clamp(0.0, 1.0);
  }

  /// Clear all registered hints.
  void clear() => _hints.clear();
}

/// Default Kurdish Sorani (ckb) keyword hints for AURA.
///
/// These cover common interaction patterns in Kurdish Sorani.
/// Extensible — more can be added without code changes.
final List<ReactionKeywordHint> defaultCkbHints = [
  // Help / assistance
  const ReactionKeywordHint(
    keyword: 'یارمەتی',
    language: 'ckb',
    category: 'agent',
    tags: ['feedback'],
    boost: 0.15,
  ),
  // Greeting
  const ReactionKeywordHint(
    keyword: 'سڵاو',
    language: 'ckb',
    category: 'personality',
    tags: ['personality'],
    boost: 0.2,
  ),
  // Error / problem
  const ReactionKeywordHint(
    keyword: 'کێشە',
    language: 'ckb',
    category: 'error',
    tags: ['error'],
    boost: 0.15,
  ),
  // Thanks / gratitude
  const ReactionKeywordHint(
    keyword: 'سوپاس',
    language: 'ckb',
    category: 'personality',
    tags: ['personality', 'confirmation'],
    boost: 0.2,
  ),
  // Search / query
  const ReactionKeywordHint(
    keyword: 'گەڕان',
    language: 'ckb',
    category: 'agent',
    tags: ['progress'],
    boost: 0.1,
  ),
  // Yes / confirmation
  const ReactionKeywordHint(
    keyword: 'بەڵێ',
    language: 'ckb',
    category: 'agent',
    tags: ['confirmation'],
    boost: 0.15,
  ),
  // No / denial
  const ReactionKeywordHint(
    keyword: 'نەخێر',
    language: 'ckb',
    category: 'agent',
    tags: ['feedback'],
    boost: 0.1,
  ),
  // How much / quantity
  const ReactionKeywordHint(
    keyword: 'چەند',
    language: 'ckb',
    category: 'agent',
    tags: ['feedback'],
    boost: 0.1,
  ),
  // Good / nice
  const ReactionKeywordHint(
    keyword: 'باش',
    language: 'ckb',
    category: 'personality',
    tags: ['personality', 'confirmation'],
    boost: 0.15,
  ),
  // Wait
  const ReactionKeywordHint(
    keyword: 'چاوەڕوانبە',
    language: 'ckb',
    category: 'agent',
    tags: ['progress'],
    boost: 0.1,
  ),
];

/// Default English (en) keyword hints for AURA.
final List<ReactionKeywordHint> defaultEnHints = [
  const ReactionKeywordHint(
    keyword: 'help',
    language: 'en',
    category: 'agent',
    tags: ['feedback'],
    boost: 0.15,
  ),
  const ReactionKeywordHint(
    keyword: 'hello',
    language: 'en',
    category: 'personality',
    tags: ['personality'],
    boost: 0.2,
  ),
  const ReactionKeywordHint(
    keyword: 'error',
    language: 'en',
    category: 'error',
    tags: ['error'],
    boost: 0.15,
  ),
  const ReactionKeywordHint(
    keyword: 'thanks',
    language: 'en',
    category: 'personality',
    tags: ['personality', 'confirmation'],
    boost: 0.2,
  ),
  const ReactionKeywordHint(
    keyword: 'search',
    language: 'en',
    category: 'agent',
    tags: ['progress'],
    boost: 0.1,
  ),
  const ReactionKeywordHint(
    keyword: 'yes',
    language: 'en',
    category: 'agent',
    tags: ['confirmation'],
    boost: 0.15,
  ),
  const ReactionKeywordHint(
    keyword: 'no',
    language: 'en',
    category: 'agent',
    tags: ['feedback'],
    boost: 0.1,
  ),
  const ReactionKeywordHint(
    keyword: 'wait',
    language: 'en',
    category: 'agent',
    tags: ['progress'],
    boost: 0.1,
  ),
];
