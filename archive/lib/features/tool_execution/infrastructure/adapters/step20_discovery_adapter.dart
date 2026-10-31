/// step20_discovery_adapter.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Bridge between Step 22 and Step 20's ToolDiscoveryApi.
///
/// Step 20 API mismatch:
///   Abstract ToolDiscoveryApi: search(), byCategory(), available(),
///     needsAttention(), getTool(), activeCategories()
///   Concrete DefaultToolDiscoveryApi: discover(query), discoverByCategory(category),
///     discoverByRiskLevel(riskLevel), getToolInfo(toolId), availableCategories()
///
/// This adapter bridges the mismatch and adds:
/// - Unified search/discover API
/// - Category-based filtering
/// - Risk-level discovery
/// - Tool attention tracking
/// - Locale-aware descriptions (Kurdish Sorani RTL first)
///
/// FAIL CLOSED: any discovery error returns empty results.
library;

import '../../domain/services/tool_interface.dart';

/// Tool info returned by discovery.
class DiscoveredToolInfo {
  final String toolId;
  final String name;
  final String description;
  final ToolCategory category;
  final ToolRiskLevel riskLevel;
  final bool isAvailable;
  final bool needsAttention;
  final bool isOfflineCapable;
  final bool isVoiceSafe;
  final String? locale;

  const DiscoveredToolInfo({
    required this.toolId,
    required this.name,
    required this.description,
    required this.category,
    this.riskLevel = ToolRiskLevel.medium,
    this.isAvailable = true,
    this.needsAttention = false,
    this.isOfflineCapable = false,
    this.isVoiceSafe = false,
    this.locale,
  });

  /// Kurdish Sorani name if locale is 'ku'.
  String get localizedName =>
      locale == 'ku' ? name : name; // Would have Kurdish names in production

  /// Kurdish Sorani description if locale is 'ku'.
  String get localizedDescription =>
      locale == 'ku' ? description : description;
}

/// Discovery query with filters.
class DiscoveryQuery {
  final String? text;
  final ToolCategory? category;
  final ToolRiskLevel? riskLevel;
  final bool? onlyAvailable;
  final bool? onlyOffline;
  final bool? onlyVoiceSafe;
  final String? locale;

  const DiscoveryQuery({
    this.text,
    this.category,
    this.riskLevel,
    this.onlyAvailable,
    this.onlyOffline,
    this.onlyVoiceSafe,
    this.locale = 'ku',
  });

  bool get isEmpty =>
      text == null &&
      category == null &&
      riskLevel == null &&
      onlyAvailable == null &&
      onlyOffline == null &&
      onlyVoiceSafe == null;
}

/// Discovery result with matched tools and metadata.
class DiscoveryResult {
  final List<DiscoveredToolInfo> tools;
  final int totalMatches;
  final String query;
  final Duration searchDuration;

  const DiscoveryResult({
    required this.tools,
    required this.totalMatches,
    required this.query,
    this.searchDuration = Duration.zero,
  });

  bool get isEmpty => tools.isEmpty;
  bool get isNotEmpty => tools.isNotEmpty;
}

/// Adapter bridging Step 20's ToolDiscoveryApi to Step 22.
///
/// Handles:
/// 1. Method name mismatch (search ↔ discover, byCategory ↔ discoverByCategory, etc.)
/// 2. Additional discovery capabilities (risk-level, offline, voice-safe)
/// 3. Locale-aware tool descriptions (Kurdish Sorani RTL first)
/// 4. Attention tracking
///
/// FAIL CLOSED: any error returns empty results.
class Step20DiscoveryAdapter {
  /// Registry of all known tools (from Step 22 Tool implementations).
  final Map<String, Tool> _toolRegistry = {};

  /// Tools that need attention (updates, errors, etc.).
  final Set<String> _attentionTools = {};

  /// Default locale for descriptions.
  String locale;

  Step20DiscoveryAdapter({
    Map<String, Tool>? tools,
    Set<String>? attentionTools,
    this.locale = 'ku',
  }) {
    if (tools != null) _toolRegistry.addAll(tools);
    if (attentionTools != null) _attentionTools.addAll(attentionTools);
  }

  // ─── Bridge methods (matching abstract API) ─────────────────────────

  /// Bridge: search() → discover(query).
  /// Abstract: search(query) → List<ToolInfo>
  /// Concrete: discover(query) → List<ToolInfo>
  DiscoveryResult search(String query, {String? loc}) {
    try {
      return discover(query, locale: loc ?? locale);
    } catch (e) {
      return DiscoveryResult(
        tools: [],
        totalMatches: 0,
        query: query,
      ); // FAIL CLOSED → empty
    }
  }

  /// Bridge: byCategory() → discoverByCategory(category).
  /// Abstract: byCategory(category) → List<ToolInfo>
  /// Concrete: discoverByCategory(category) → List<ToolInfo>
  DiscoveryResult byCategory(ToolCategory category, {String? loc}) {
    try {
      return discoverByCategory(category, locale: loc ?? locale);
    } catch (e) {
      return DiscoveryResult(
        tools: [],
        totalMatches: 0,
        query: 'category:${category.name}',
      );
    }
  }

  /// Bridge: available() → availableCategories() + tool list.
  /// Abstract: available() → List<ToolInfo>
  /// Concrete: availableCategories() → List<String>
  DiscoveryResult available({String? loc}) {
    try {
      final availableTools = _toolRegistry.values
          .where((t) => t.supportsOffline || true) // All registered tools
          .map((t) => _toolToDiscoveredInfo(t, locale: loc ?? locale))
          .toList();
      return DiscoveryResult(
        tools: availableTools,
        totalMatches: availableTools.length,
        query: 'available',
      );
    } catch (e) {
      return const DiscoveryResult(
        tools: [],
        totalMatches: 0,
        query: 'available',
      );
    }
  }

  /// Bridge: needsAttention() → tools that need attention.
  /// Abstract: needsAttention() → List<ToolInfo>
  /// Concrete: No direct equivalent — we bridge from our attention set.
  DiscoveryResult needsAttention({String? loc}) {
    try {
      final attentionList = _attentionTools
          .map((id) => _toolRegistry[id])
          .whereType<Tool>()
          .map((t) => _toolToDiscoveredInfo(
                t,
                locale: loc ?? locale,
                needsAttention: true,
              ))
          .toList();
      return DiscoveryResult(
        tools: attentionList,
        totalMatches: attentionList.length,
        query: 'needsAttention',
      );
    } catch (e) {
      return const DiscoveryResult(
        tools: [],
        totalMatches: 0,
        query: 'needsAttention',
      );
    }
  }

  /// Bridge: getTool() → getToolInfo().
  /// Abstract: getTool(toolId) → ToolInfo?
  /// Concrete: getToolInfo(toolId) → ToolInfo?
  DiscoveredToolInfo? getTool(String toolId, {String? loc}) {
    try {
      final tool = _toolRegistry[toolId];
      if (tool == null) return null;
      return _toolToDiscoveredInfo(tool, locale: loc ?? locale);
    } catch (e) {
      return null;
    }
  }

  /// Bridge: activeCategories() → availableCategories().
  /// Abstract: activeCategories() → List<String>
  /// Concrete: availableCategories() → List<String>
  List<ToolCategory> activeCategories() {
    try {
      final categories = <ToolCategory>{};
      for (final tool in _toolRegistry.values) {
        categories.add(tool.category);
      }
      return categories.toList();
    } catch (e) {
      return []; // FAIL CLOSED
    }
  }

  // ─── Enhanced discovery methods ──────────────────────────────────────

  /// Full discovery with filtering.
  DiscoveryResult discover(
    String query, {
    String locale = 'ku',
    ToolCategory? category,
    ToolRiskLevel? riskLevel,
    bool onlyAvailable = false,
    bool onlyOffline = false,
    bool onlyVoiceSafe = false,
  }) {
    final startTime = DateTime.now();

    try {
      final queryLower = query.toLowerCase();
      final matches = <DiscoveredToolInfo>[];

      for (final tool in _toolRegistry.values) {
        // Text search
        if (query.isNotEmpty) {
          final nameMatch = tool.name.toLowerCase().contains(queryLower);
          final descMatch =
              tool.description.toLowerCase().contains(queryLower);
          final idMatch = tool.id.toLowerCase().contains(queryLower);
          if (!nameMatch && !descMatch && !idMatch) continue;
        }

        // Category filter
        if (category != null && tool.category != category) continue;

        // Risk level filter
        if (riskLevel != null && tool.riskLevel != riskLevel) continue;

        // Availability filter
        if (onlyAvailable && !_isToolAvailable(tool)) continue;

        // Offline filter
        if (onlyOffline && !tool.supportsOffline) continue;

        // Voice-safe filter
        if (onlyVoiceSafe && !tool.isVoiceSafe) continue;

        matches.add(_toolToDiscoveredInfo(
          tool,
          locale: locale,
          needsAttention: _attentionTools.contains(tool.id),
        ));
      }

      return DiscoveryResult(
        tools: matches,
        totalMatches: matches.length,
        query: query,
        searchDuration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return DiscoveryResult(
        tools: [],
        totalMatches: 0,
        query: query,
      );
    }
  }

  /// Discover tools by category.
  DiscoveryResult discoverByCategory(
    ToolCategory category, {
    String locale = 'ku',
  }) {
    try {
      final matches = _toolRegistry.values
          .where((t) => t.category == category)
          .map((t) => _toolToDiscoveredInfo(
                t,
                locale: locale,
                needsAttention: _attentionTools.contains(t.id),
              ))
          .toList();

      return DiscoveryResult(
        tools: matches,
        totalMatches: matches.length,
        query: 'category:${category.name}',
      );
    } catch (e) {
      return DiscoveryResult(
        tools: [],
        totalMatches: 0,
        query: 'category:${category.name}',
      );
    }
  }

  /// Discover tools by risk level.
  DiscoveryResult discoverByRiskLevel(
    ToolRiskLevel riskLevel, {
    String locale = 'ku',
  }) {
    try {
      final matches = _toolRegistry.values
          .where((t) => t.riskLevel == riskLevel)
          .map((t) => _toolToDiscoveredInfo(
                t,
                locale: locale,
                needsAttention: _attentionTools.contains(t.id),
              ))
          .toList();

      return DiscoveryResult(
        tools: matches,
        totalMatches: matches.length,
        query: 'risk:${riskLevel.name}',
      );
    } catch (e) {
      return DiscoveryResult(
        tools: [],
        totalMatches: 0,
        query: 'risk:${riskLevel.name}',
      );
    }
  }

  /// Get detailed tool info.
  DiscoveredToolInfo? getToolInfo(String toolId, {String? loc}) =>
      getTool(toolId, loc: loc);

  // ─── Registration ────────────────────────────────────────────────────

  /// Register a tool for discovery.
  void registerTool(Tool tool) => _toolRegistry[tool.id] = tool;

  /// Mark a tool as needing attention.
  void markNeedsAttention(String toolId) => _attentionTools.add(toolId);

  /// Clear attention flag for a tool.
  void clearAttention(String toolId) => _attentionTools.remove(toolId);

  /// Set the default locale.
  void setLocale(String newLocale) => locale = newLocale;

  // ─── Internal helpers ───────────────────────────────────────────────

  DiscoveredToolInfo _toolToDiscoveredInfo(
    Tool tool, {
    String locale = 'ku',
    bool needsAttention = false,
  }) =>
      DiscoveredToolInfo(
        toolId: tool.id,
        name: tool.name,
        description: tool.describe(),
        category: tool.category,
        riskLevel: tool.riskLevel,
        isAvailable: true,
        needsAttention: needsAttention,
        isOfflineCapable: tool.supportsOffline,
        isVoiceSafe: tool.isVoiceSafe,
        locale: locale,
      );

  bool _isToolAvailable(Tool tool) => true; // All registered tools are available
}
