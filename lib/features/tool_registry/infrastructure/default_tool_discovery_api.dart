/// default_tool_discovery_api.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Concrete implementation of [ToolDiscoveryApi].
///
/// Delegates to [ToolRegistryService] for lookups.
/// FAIL CLOSED: unknown tools never appear in results.
library;

import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/models.dart';
import 'package:aura_assistant/features/tool_registry/domain/services/services.dart';
import 'package:aura_assistant/features/tool_registry/application/application.dart';

/// Concrete implementation of [ToolDiscoveryApi].
///
/// Wraps [ToolRegistryService] to provide discovery functionality.
/// Only allowed, enabled tools appear in discovery results.
class DefaultToolDiscoveryApi implements ToolDiscoveryApi {
  final ToolRegistryService _registryService;

  DefaultToolDiscoveryApi({
    required ToolRegistryService registryService,
  }) : _registryService = registryService;

  @override
  DiscoveryResult discover(String query) {
    final registryResult = _registryService.discover(query);

    if (registryResult.isFailure) {
      // FAIL CLOSED: discovery failure = empty result with error.
      return DiscoveryResult(
        tools: [],
        totalCount: 0,
        query: query,
        hasMore: false,
        errorMessage: 'Discovery failed: '
            '${registryResult.asFailure.error}',
      );
    }

    final allMatches = registryResult.asSuccess.value;

    // Filter: only allowed + enabled tools are discoverable.
    final discoverable = allMatches.where((d) {
      return d.isEnabled && _registryService.isAllowed(d.toolId);
    }).toList();

    return DiscoveryResult(
      tools: discoverable
          .map((d) => DiscoveredTool.fromDefinition(d))
          .toList(),
      totalCount: discoverable.length,
      query: query,
      hasMore: false,
    );
  }

  @override
  DiscoveryResult discoverByCategory(ToolCategory category) {
    final tools = _registryService.getByCategory(category);

    // Filter: only allowed + enabled.
    final discoverable = tools.where((d) {
      return d.isEnabled && _registryService.isAllowed(d.toolId);
    }).toList();

    return DiscoveryResult(
      tools: discoverable
          .map((d) => DiscoveredTool.fromDefinition(d))
          .toList(),
      totalCount: discoverable.length,
      query: category.name,
      hasMore: false,
    );
  }

  @override
  DiscoveryResult discoverByRiskLevel(ToolRiskLevel riskLevel) {
    final allTools = _registryService.getAll();

    final matching = allTools.where((d) => d.riskLevel == riskLevel);

    // Filter: only allowed + enabled.
    final discoverable = matching.where((d) {
      return d.isEnabled && _registryService.isAllowed(d.toolId);
    }).toList();

    return DiscoveryResult(
      tools: discoverable
          .map((d) => DiscoveredTool.fromDefinition(d))
          .toList(),
      totalCount: discoverable.length,
      query: 'risk:${riskLevel.name}',
      hasMore: false,
    );
  }

  @override
  DiscoveredTool? getToolInfo(String toolId) {
    final result = _registryService.getDefinition(toolId);
    if (result.isFailure) {
      // FAIL CLOSED: not found = null.
      return null;
    }

    final definition = result.asSuccess.value;

    // Only return info for allowed + enabled tools.
    if (!definition.isEnabled || !_registryService.isAllowed(toolId)) {
      return null;
    }

    return DiscoveredTool.fromDefinition(definition);
  }

  @override
  List<ToolCategory> availableCategories() {
    final allTools = _registryService.getAll();

    // Only include categories that have at least one allowed + enabled tool.
    final categories = <ToolCategory>{};
    for (final d in allTools) {
      if (d.isEnabled && _registryService.isAllowed(d.toolId)) {
        categories.add(d.effectiveCategory);
      }
    }

    return categories.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
  }
}
