/// tool_registry_repository.dart
/// AURA Assistant – Step 25: Adapter target for Step 20 ToolRegistryRepository
///
/// Exact signature match from Step 23.
/// This interface MUST be implemented by Step20ToolRegistryAdapter.
library;

/// Represents a discovered tool from the tool registry.
class DiscoveredTool {
  final String toolId;
  final String name;
  final String description;
  final String category;
  final Map<String, dynamic> parameters;
  final double relevanceScore;

  const DiscoveredTool({
    required this.toolId,
    required this.name,
    this.description = '',
    this.category = '',
    this.parameters = const {},
    this.relevanceScore = 0.0,
  });

  @override
  String toString() => 'DiscoveredTool(id: $toolId, name: $name, score: $relevanceScore)';
}

/// Abstract repository matching Step 23's ToolRegistryRepository.
/// discover(category, userRequest) → List<DiscoveredTool>
/// get(toolId) → DiscoveredTool?
/// allTools() → List<DiscoveredTool>
/// byCategory(category) → List<DiscoveredTool>
/// selectBest(candidates, userRequest) → DiscoveredTool?
abstract class ToolRegistryRepository {
  Future<List<DiscoveredTool>> discover(String category, String userRequest);
  Future<DiscoveredTool?> get(String toolId);
  Future<List<DiscoveredTool>> allTools();
  Future<List<DiscoveredTool>> byCategory(String category);
  Future<DiscoveredTool?> selectBest(
    List<DiscoveredTool> candidates,
    String userRequest,
  );
}
