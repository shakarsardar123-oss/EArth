/// Registry for reaction definitions — follows the [ToolRegistry] pattern.
///
/// A simple [Map]-based registry with register/unregister/get/has, plus
/// category and tag filtering. The catalog is populated at startup with
/// all available reaction definitions and queried by the selector.
///
/// No allowlist / security features — those belong to a future step.
library;

import 'reaction_model.dart';
import 'reaction_trigger.dart';

class ReactionCatalog {
  final Map<String, Reaction> _reactions = {};

  /// Registers a reaction. Overwrites if a reaction with the same id
  /// already exists.
  void register(Reaction reaction) {
    _reactions[reaction.id] = reaction;
  }

  /// Unregisters a reaction by id.
  void unregister(String id) {
    _reactions.remove(id);
  }

  /// Returns the reaction with [id], or null if not found.
  Reaction? get(String id) => _reactions[id];

  /// Returns the reaction with [id], or throws if not found.
  Reaction getOrThrow(String id) {
    final reaction = _reactions[id];
    if (reaction == null) {
      throw StateError('Reaction not found: $id');
    }
    return reaction;
  }

  /// Whether a reaction with [id] is registered.
  bool has(String id) => _reactions.containsKey(id);

  /// All registered reactions.
  List<Reaction> get all => List.unmodifiable(_reactions.values);

  /// Number of registered reactions.
  int get count => _reactions.length;

  /// Returns reactions that match the given [trigger].
  List<Reaction> getByTrigger(ReactionTrigger trigger) =>
      _reactions.values.where((r) => r.trigger == trigger).toList();

  /// Returns reactions filtered by category.
  List<Reaction> getByCategory(String category) =>
      _reactions.values.where((r) => r.category == category).toList();

  /// Returns reactions that have any of the given tags.
  List<Reaction> getByTags(List<String> tags) => _reactions.values
      .where((r) => r.tags.any((tag) => tags.contains(tag)))
      .toList();

  /// Returns reactions matching both trigger and category.
  List<Reaction> getByTriggerAndCategory(
    ReactionTrigger trigger,
    String category,
  ) =>
      _reactions.values
          .where((r) => r.trigger == trigger && r.category == category)
          .toList();

  /// Returns all reaction ids.
  List<String> get ids => List.unmodifiable(_reactions.keys);

  /// Clears all registered reactions.
  void clear() => _reactions.clear();
}
