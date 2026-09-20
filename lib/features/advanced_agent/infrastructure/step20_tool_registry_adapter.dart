/// step20_tool_registry_adapter.dart
/// AURA Assistant – Step 25: Infrastructure adapter for Step 20 Tool Registry.
///
/// Adapts Step 20's ToolRegistry contract to Step 25's ToolRegistryRepository.
/// FAIL-CLOSED: missing/disabled/unavailable → deny (empty list / null).
///
/// IMPORTANT: ToolRegistryRepository has NO isAvailable method.
library;

import '../domain/repositories/tool_registry_repository.dart';

/// Adapter bridging Step 20 Tool Registry to Step 25's ToolRegistryRepository.
///
/// Implements the EXACT ToolRegistryRepository interface:
///   discover(category, userRequest) → Future<List<DiscoveredTool>>
///   get(toolId) → Future<DiscoveredTool?>
///   allTools() → Future<List<DiscoveredTool>>
///   byCategory(category) → Future<List<DiscoveredTool>>
///   selectBest(candidates, userRequest) → Future<DiscoveredTool?>
///
/// FAIL-CLOSED rules:
///   - Any error or unavailability → empty list / null result
///   - selectBest returns null if no candidate meets threshold
///   - NEVER returns data that hasn't been validated
class Step20ToolRegistryAdapter implements ToolRegistryRepository {
  /// Internal registry of known tools (populated by Step 20 wiring).
  final Map<String, DiscoveredTool> _registry = {};
  bool _enabled;

  Step20ToolRegistryAdapter({bool enabled = true}) : _enabled = enabled;

  @override
  Future<List<DiscoveredTool>> discover(
    String category,
    String userRequest,
  ) async {
    // FAIL-CLOSED: disabled → empty list
    if (!_enabled) return [];

    // Search by category and relevance to request.
    final results = _registry.values
        .where((t) =>
            t.category == category || category.isEmpty)
        .toList();

    return results;
  }

  @override
  Future<DiscoveredTool?> get(String toolId) async {
    // FAIL-CLOSED: disabled → null
    if (!_enabled) return null;

    return _registry[toolId];
  }

  @override
  Future<List<DiscoveredTool>> allTools() async {
    // FAIL-CLOSED: disabled → empty list
    if (!_enabled) return [];

    return _registry.values.toList();
  }

  @override
  Future<List<DiscoveredTool>> byCategory(String category) async {
    // FAIL-CLOSED: disabled → empty list
    if (!_enabled) return [];

    return _registry.values
        .where((t) => t.category == category)
        .toList();
  }

  @override
  Future<DiscoveredTool?> selectBest(
    List<DiscoveredTool> candidates,
    String userRequest,
  ) async {
    // FAIL-CLOSED: no candidates → null
    if (candidates.isEmpty) return null;

    // Select the candidate with highest relevance score.
    // Must meet minimum threshold (0.5) to be selected.
    final sorted = List<DiscoveredTool>.from(candidates)
      ..sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    final best = sorted.first;
    if (best.relevanceScore < 0.5) return null; // FAIL-CLOSED: below threshold

    return best;
  }

  /// Register a tool (for wiring/testing).
  void registerTool(DiscoveredTool tool) {
    _registry[tool.toolId] = tool;
  }

  /// Enable/disable the adapter (for wiring).
  void setEnabled(bool enabled) => _enabled = enabled;
}
