/// Step 23 — Tool Registry Repository Interface
///
/// Contract for the Step 20 Tool Registry adapter.
/// Uses existing Step 20 APIs: get(), allTools, byCategory().

abstract class ToolRegistryRepository {
  /// Discover tools matching a category or capability.
  /// Returns empty list if none found (FAIL-CLOSED → no tool selected).
  Future<List<DiscoveredTool>> discover(String? category, String userRequest);

  /// Get a specific tool by its ID.
  /// Returns null if not found or not in allowlist (FAIL-CLOSED).
  Future<DiscoveredTool?> get(String toolId);

  /// List all available tools.
  Future<List<DiscoveredTool>> allTools();

  /// List tools by category.
  Future<List<DiscoveredTool>> byCategory(String category);

  /// Select the best tool from discovered candidates.
  /// Returns null if no suitable tool (FAIL-CLOSED).
  Future<DiscoveredTool?> selectBest(List<DiscoveredTool> candidates, String userRequest);
}

/// Lightweight tool descriptor returned by discovery.
class DiscoveredTool {
  final String toolId;
  final String name;
  final String description;
  final String category;
  final String riskLevel; // String per Step 20 contract (not enum)
  final bool isLocal; // true = works offline
  final bool requiresCloud; // true = requires internet

  const DiscoveredTool({
    required this.toolId,
    required this.name,
    required this.description,
    required this.category,
    required this.riskLevel,
    this.isLocal = false,
    this.requiresCloud = false,
  });
}
