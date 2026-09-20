/// Step 22 — Tool Executor Registry (executors/ — canonical)
///
/// Registry for tool executors with filtering and validation.
///
/// AUDIT FIX — Bug #3/#10:
///   - Changed `byRiskLevel(ToolRiskLevel riskLevel)` → `byRiskLevel(String riskLevel)`
///     Tool.riskLevel is String per tool_interface.dart, NOT an enum.
///   - Changed `tool.riskLevel != ToolRiskLevel.low` → `tool.riskLevel != 'low'`
///   - Added string validation for riskLevel parameter (valid values: low, medium, high, critical)
///   - Removed ToolRiskLevel enum import (does not exist)
///   - Removed RegistryValidationIssue / ValidationSeverity — replaced with simple
///     ValidationIssue class using String severity and message.
///   - FAIL-CLOSED: invalid risk level strings default to 'critical' for safety.

import '../../domain/services/tool_interface.dart';

/// Valid risk level strings per tool_interface.dart.
const _validRiskLevels = {'low', 'medium', 'high', 'critical'};

/// Simple validation issue — replaces phantom RegistryValidationIssue/ValidationSeverity.
class ValidationIssue {
  final String severity;
  final String message;

  const ValidationIssue({
    required this.severity,
    required this.message,
  });

  @override
  String toString() => 'ValidationIssue($severity): $message';
}

/// Registry entry wrapping a Tool with metadata.
class RegisteredTool {
  final Tool tool;
  final DateTime registeredAt;
  final String registeredBy;

  const RegisteredTool({
    required this.tool,
    required this.registeredAt,
    required this.registeredBy,
  });
}

/// Tool Executor Registry — tracks all registered tool executors.
class ToolExecutorRegistry {
  final Map<String, RegisteredTool> _tools = {};

  /// Register a tool executor.
  void register(Tool tool, {required String registeredBy}) {
    _tools[tool.id] = RegisteredTool(
      tool: tool,
      registeredAt: DateTime.now(),
      registeredBy: registeredBy,
    );
  }

  /// Unregister a tool by ID.
  void unregister(String toolId) {
    _tools.remove(toolId);
  }

  /// Get a tool by ID. Returns null if not found (fail-closed: caller must deny).
  Tool? get(String toolId) {
    return _tools[toolId]?.tool;
  }

  /// List all registered tools.
  List<Tool> get all => _tools.values.map((e) => e.tool).toList();

  /// Filter tools by risk level.
  /// [riskLevel] must be a valid String: 'low', 'medium', 'high', 'critical'.
  /// FAIL-CLOSED: if riskLevel is not a valid string, returns empty list (deny by default).
  List<Tool> byRiskLevel(String riskLevel) {
    if (!_validRiskLevels.contains(riskLevel)) {
      return []; // Fail-closed: invalid risk level → deny all access
    }
    return _tools.values
        .where((entry) => entry.tool.riskLevel == riskLevel)
        .map((e) => e.tool)
        .toList();
  }

  /// Filter tools that require confirmation (riskLevel != 'low').
  /// FAIL-CLOSED: if riskLevel is not a recognized string, treat as requiring confirmation.
  List<Tool> get requiringConfirmation {
    return _tools.values
        .where((entry) {
          final level = entry.tool.riskLevel;
          if (!_validRiskLevels.contains(level)) {
            return true; // Unknown risk level → require confirmation (fail-closed)
          }
          return level != 'low';
        })
        .map((e) => e.tool)
        .toList();
  }

  /// Validate the registry state and return any issues.
  List<ValidationIssue> validate() {
    final issues = <ValidationIssue>[];
    for (final entry in _tools.values) {
      final tool = entry.tool;
      // Check risk level is a valid string
      if (!_validRiskLevels.contains(tool.riskLevel)) {
        issues.add(ValidationIssue(
          severity: 'error',
          message: 'Tool ${tool.id} has invalid riskLevel: "${tool.riskLevel}"',
        ));
      }
      // Check tool has non-empty ID
      if (tool.id.isEmpty) {
        issues.add(ValidationIssue(
          severity: 'error',
          message: 'Tool has empty id',
        ));
      }
    }
    return issues;
  }

  /// Number of registered tools.
  int get count => _tools.length;

  /// Check if a tool is registered by ID.
  bool contains(String toolId) => _tools.containsKey(toolId);
}
