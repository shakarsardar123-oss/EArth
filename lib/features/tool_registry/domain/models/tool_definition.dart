/// tool_definition.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Core domain model for a registered tool. Follows the ActionMetadata
/// pattern from Step 19 but extends it with tool-specific concerns:
///   - category, confirmation policy, version, enabled state, icon key
///   - FAIL CLOSED: disabled tools are never executable
///   - FAIL CLOSED: unknown category → treated as highest risk
///
/// @immutable + copyWith with clear* bool flags (see SecurityConfig pattern).
library;

import 'package:flutter/foundation.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/tool_category.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/confirmation_policy.dart';

/// Risk levels a tool can have. Mirrors Step 19's ActionRiskLevel but
/// is defined here in tool-registry domain to avoid coupling.
///
/// FAIL CLOSED: [unknown] → treated as [critical].
enum ToolRiskLevel {
  /// No risk — read-only, no data access.
  none,

  /// Low risk — limited state changes, no sensitive data.
  low,

  /// Medium risk — moderate state changes or access to non-critical data.
  medium,

  /// High risk — significant state changes or access to sensitive data.
  high,

  /// Critical risk — irreversible operations or access to highly
  /// sensitive data (passwords, auth tokens, financial). NEVER auto-execute.
  critical,

  /// Risk could not be determined. FAIL CLOSED → [critical].
  unknown,
}

/// Extension for [ToolRiskLevel].
extension ToolRiskLevelX on ToolRiskLevel {
  /// Resolve effective risk. FAIL CLOSED: [unknown] → [critical].
  ToolRiskLevel get effective =>
      this == ToolRiskLevel.unknown ? ToolRiskLevel.critical : this;

  /// Whether this risk level is considered dangerous.
  /// FAIL CLOSED: [unknown] → true.
  bool get isDangerous =>
      effective == ToolRiskLevel.high || effective == ToolRiskLevel.critical;

  /// Human-readable label.
  String get label => switch (this) {
        ToolRiskLevel.none => 'None',
        ToolRiskLevel.low => 'Low',
        ToolRiskLevel.medium => 'Medium',
        ToolRiskLevel.high => 'High',
        ToolRiskLevel.critical => 'Critical',
        ToolRiskLevel.unknown => 'Unknown (→ Critical)',
      };
}

/// Core domain model representing a registered tool in the AURA Assistant.
///
/// Every tool that the agent can discover or execute MUST have a
/// [ToolDefinition] in the [ToolRegistryService]. Tools without a
/// definition are UNKNOWN → FAIL CLOSED → denied.
///
/// Inspired by Step 19's [ActionMetadata] but with tool-specific fields:
///   - [category], [confirmationPolicy], [isEnabled], [version], [iconKey]
///
/// @immutable + copyWith with clear* bool flags for list fields.
@immutable
class ToolDefinition {
  /// Unique identifier for this tool (e.g. 'voice_recognize', 'memory_remember').
  final String toolId;

  /// Human-readable name (displayed to user).
  final String name;

  /// Human-readable description (displayed to user for confirmation dialogs).
  final String description;

  /// Category this tool belongs to. FAIL CLOSED: [unknown] → highest risk.
  final ToolCategory category;

  /// Risk level of this tool. FAIL CLOSED: [unknown] → [critical].
  final ToolRiskLevel riskLevel;

  /// When user confirmation is required before execution.
  final ConfirmationPolicy confirmationPolicy;

  /// Sensitive data categories this tool may access (from Step 19).
  ///
  /// Stored as string identifiers to avoid direct import coupling.
  /// Values should match Step 19's [SensitiveDataCategory] names:
  ///   'password', 'apiKey', 'authToken', 'creditCard', 'nationalId',
  ///   'email', 'phone', 'ipAddress', 'address', 'dateOfBirth',
  ///   'medicalRecord', 'financialAccount', 'biometricId', 'privateKey',
  ///   'connectionString', 'memoryPolicySensitive', 'unknown'
  final List<String> accessedCategories;

  /// Whether this tool requires network access.
  final bool requiresNetwork;

  /// Whether this tool modifies system/device state.
  final bool modifiesState;

  /// Whether this tool could exfiltrate data (e.g. sends data over network).
  final bool canExfiltrateData;

  /// Whether this tool is currently enabled.
  ///
  /// Disabled tools are still in the registry (for discovery) but
  /// CANNOT be executed. FAIL CLOSED: disabled → denied.
  final bool isEnabled;

  /// Semantic version of the tool definition (for migration tracking).
  final String version;

  /// Icon key for UI rendering (maps to an icon in the asset bundle).
  final String iconKey;

  /// Tags for search / discovery.
  final List<String> tags;

  /// Required device permissions (from Step 16's DevicePermission enum names).
  ///
  /// Stored as string identifiers to avoid direct import coupling.
  /// Values should match Step 16's [DevicePermission] names:
  ///   'accessibility', 'overlay', 'screenCapture', 'microphone', 'camera',
  ///   'storage', 'notification', 'batteryOptimization', 'assistant', 'location'
  final List<String> requiredPermissions;

  const ToolDefinition({
    required this.toolId,
    required this.name,
    required this.description,
    this.category = ToolCategory.unknown,
    this.riskLevel = ToolRiskLevel.unknown,
    this.confirmationPolicy = ConfirmationPolicy.unknown,
    this.accessedCategories = const [],
    this.requiresNetwork = false,
    this.modifiesState = false,
    this.canExfiltrateData = false,
    this.isEnabled = true,
    this.version = '1.0.0',
    this.iconKey = '',
    this.tags = const [],
    this.requiredPermissions = const [],
  });

  /// Whether this tool is considered dangerous.
  /// FAIL CLOSED: unknown risk or category → dangerous.
  bool get isDangerous =>
      riskLevel.isDangerous || category.isInherentlyRisky;

  /// Whether this tool accesses any sensitive data categories.
  bool get accessesSensitiveData => accessedCategories.isNotEmpty;

  /// Effective risk level (resolving [unknown] → [critical]).
  ToolRiskLevel get effectiveRiskLevel => riskLevel.effective;

  /// Effective confirmation policy (resolving [unknown] → [always]).
  ConfirmationPolicy get effectiveConfirmationPolicy =>
      confirmationPolicy.effective;

  /// Effective category (resolving [unknown] → highest risk treatment).
  ToolCategory get effectiveCategory =>
      category == ToolCategory.unknown ? ToolCategory.system : category;

  /// Whether the tool can be executed.
  /// FAIL CLOSED: disabled or unknown risk → not executable.
  bool get isExecutable => isEnabled && riskLevel != ToolRiskLevel.unknown;

  /// copyWith with clear* bool flags for list fields.
  ///
  /// Follows the SecurityConfig pattern: pass `clearAccessedCategories: true`
  /// to set `accessedCategories` to an empty list, regardless of what
  /// `accessedCategories` parameter is set to.
  ToolDefinition copyWith({
    String? toolId,
    String? name,
    String? description,
    ToolCategory? category,
    ToolRiskLevel? riskLevel,
    ConfirmationPolicy? confirmationPolicy,
    List<String>? accessedCategories,
    bool clearAccessedCategories = false,
    bool? requiresNetwork,
    bool? modifiesState,
    bool? canExfiltrateData,
    bool? isEnabled,
    String? version,
    String? iconKey,
    List<String>? tags,
    bool clearTags = false,
    List<String>? requiredPermissions,
    bool clearRequiredPermissions = false,
  }) {
    return ToolDefinition(
      toolId: toolId ?? this.toolId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      riskLevel: riskLevel ?? this.riskLevel,
      confirmationPolicy: confirmationPolicy ?? this.confirmationPolicy,
      accessedCategories: clearAccessedCategories
          ? const []
          : (accessedCategories ?? this.accessedCategories),
      requiresNetwork: requiresNetwork ?? this.requiresNetwork,
      modifiesState: modifiesState ?? this.modifiesState,
      canExfiltrateData: canExfiltrateData ?? this.canExfiltrateData,
      isEnabled: isEnabled ?? this.isEnabled,
      version: version ?? this.version,
      iconKey: iconKey ?? this.iconKey,
      tags: clearTags ? const [] : (tags ?? this.tags),
      requiredPermissions: clearRequiredPermissions
          ? const []
          : (requiredPermissions ?? this.requiredPermissions),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolDefinition &&
          runtimeType == other.runtimeType &&
          toolId == other.toolId;

  @override
  int get hashCode => toolId.hashCode;

  @override
  String toString() =>
      'ToolDefinition(toolId: $toolId, name: $name, category: $category, '
      'risk: $riskLevel, enabled: $isEnabled)';
}
