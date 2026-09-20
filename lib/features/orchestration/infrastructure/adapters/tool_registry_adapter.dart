/// Step 23 — Tool Registry Adapter
///
/// Adapter implementing [ToolRegistryRepository] by delegating to the
/// canonical core [ToolRegistry] (the SAME registry the AgentEngine uses,
/// wired via `toolRegistryProvider`). It creates NO second registry.
///
/// It exposes the registered tools to the orchestration layer as lightweight
/// [DiscoveredTool] descriptors, converting the core [ToolRiskLevel] enum to
/// the orchestration String contract at the adapter boundary only.
///
/// FAIL-CLOSED: any error → empty list / null (no tool selected).

import '../../../../core/tools/tool.dart';
import '../../../../core/tools/tool_permission.dart';
import '../../../../core/tools/tool_registry.dart';
import '../../domain/orchestration_domain.dart';

class ToolRegistryAdapter implements ToolRegistryRepository {
  /// The canonical core tool registry (injected, never constructed here).
  final ToolRegistry _registry;

  ToolRegistryAdapter(this._registry);

  @override
  Future<List<DiscoveredTool>> discover(
    String? category,
    String userRequest,
  ) async {
    try {
      // Only surface tools that are allowed by the registry allowlist,
      // preserving the Step 20 security boundary.
      final Iterable<Tool> tools = (category != null && category.isNotEmpty)
          ? _registry.getByCategory(category)
          : _registry.all;
      return tools
          .where((t) => _registry.isAllowed(t.name))
          .map(_toDiscovered)
          .toList();
    } catch (_) {
      // FAIL-CLOSED: error → empty list
      return [];
    }
  }

  @override
  Future<DiscoveredTool?> selectBest(
    List<DiscoveredTool> discovered,
    String userRequest,
  ) async {
    try {
      if (discovered.isEmpty) return null;
      // Lightweight preference: if the request explicitly names a tool or
      // one of its category keywords, prefer that candidate. This is a thin
      // selection heuristic only — it does NOT re-implement any ranking
      // engine (the core registry has none). Falls back to the first tool.
      final lower = userRequest.toLowerCase();
      for (final t in discovered) {
        if (lower.contains(t.toolId.toLowerCase()) ||
            lower.contains(t.name.toLowerCase())) {
          return t;
        }
      }
      return discovered.first;
    } catch (_) {
      // FAIL-CLOSED: error → null (no tool selected)
      return null;
    }
  }

  @override
  Future<DiscoveredTool?> get(String toolId) async {
    try {
      final tool = _registry.get(toolId);
      if (tool == null) return null;
      // Respect the allowlist — a disallowed tool is invisible (FAIL-CLOSED).
      if (!_registry.isAllowed(tool.name)) return null;
      return _toDiscovered(tool);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<DiscoveredTool>> allTools() async {
    try {
      return _registry.all
          .where((t) => _registry.isAllowed(t.name))
          .map(_toDiscovered)
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<DiscoveredTool>> byCategory(String category) async {
    try {
      return _registry
          .getByCategory(category)
          .where((t) => _registry.isAllowed(t.name))
          .map(_toDiscovered)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ────────────────────── HELPERS ──────────────────────

  /// Convert a core [Tool] to an orchestration [DiscoveredTool].
  ///
  /// Type conversion happens ONLY here (the adapter boundary):
  /// core [ToolRiskLevel] enum → String; network permission → cloud/local.
  DiscoveredTool _toDiscovered(Tool tool) {
    final def = tool.definition;
    final requiresCloud = def.permissionRequirements.any(
      (r) => r.permission == ToolPermission.network,
    );
    return DiscoveredTool(
      toolId: def.name,
      name: def.name,
      description: def.description,
      category: def.category,
      // Core ToolRiskLevel enum → orchestration String contract.
      riskLevel: def.riskLevel.name,
      // A tool that needs network is cloud-dependent; otherwise local.
      isLocal: !requiresCloud,
      requiresCloud: requiresCloud,
    );
  }
}
