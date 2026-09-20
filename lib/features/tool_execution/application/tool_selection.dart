/// tool_selection.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Tool selection service — picks the best tool for a request.
/// KEY FIXES:
///   - riskLevel is String NOT ToolRiskLevel enum
///   - registry.allTools NOT getAllTools()
///   - registry.get() NOT getTool()
///   - maxRiskLevel is String? NOT enum
///   - FAIL CLOSED: if no safe tool found, return null
library;

import '../domain/services/tool_interface.dart';
import '../infrastructure/executors/tool_executor_registry.dart';

/// Valid risk levels for comparison
const List<String> _riskLevels = ['low', 'medium', 'high', 'critical'];

int _riskIndex(String risk) {
  final idx = _riskLevels.indexOf(risk.toLowerCase());
  return idx >= 0 ? idx : 0;
}

class ToolSelectionService {
  final ToolExecutorRegistry registry;
  final String? maxRiskLevel;

  ToolSelectionService({
    required this.registry,
    this.maxRiskLevel,
  });

  /// Select the best tool for a given request.
  /// Returns null if no suitable tool found (FAIL CLOSED).
  Tool? select({required String category, String? preferredToolId}) {
    if (preferredToolId != null) {
      final tool = registry.get(preferredToolId);
      if (tool != null && _isWithinRiskLevel(tool.riskLevel)) {
        return tool;
      }
      // Preferred tool exceeds risk — FAIL CLOSED
      return null;
    }

    final tools = registry.byCategory(category);
    if (tools.isEmpty) return null;

    // Pick the lowest-risk tool that fits
    final sorted = List<Tool>.from(tools)
      ..sort((a, b) => _riskIndex(a.riskLevel).compareTo(_riskIndex(b.riskLevel)));

    for (final tool in sorted) {
      if (_isWithinRiskLevel(tool.riskLevel)) {
        return tool;
      }
    }

    // No tool within risk level — FAIL CLOSED
    return null;
  }

  /// List all available tools within risk limit.
  List<Tool> availableTools() {
    return registry.allTools.where(_isWithinRiskLevel).toList();
  }

  bool _isWithinRiskLevel(String toolRisk) {
    if (maxRiskLevel == null) return true;
    return _riskIndex(toolRisk) <= _riskIndex(maxRiskLevel!);
  }
}
