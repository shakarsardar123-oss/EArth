import 'tool_arguments.dart';
import 'tool_permission.dart';
import '../agent/retry_policy.dart';
import '../agent/agent_confirmation_manager.dart';

/// Defines a tool's metadata — name, description, parameters, and permissions.
///
/// This is used both for tool registration and for generating LLM tool schemas
/// (OpenAI function calling format).
class ToolDefinition {
  const ToolDefinition({
    required this.name,
    required this.description,
    this.category = 'general',
    this.parameters = const [],
    this.permissionRequirements = const [],
    this.isDangerous = false,
    this.requiresConfirmation = false,
    this.version = '1.0.0',
    this.tags = const [],
    this.icon,
    // Phase 4 additions:
    this.outputSchema,
    this.timeout = const Duration(seconds: 30),
    this.retryPolicy,
    this.verificationStrategy,
    this.riskLevel = ToolRiskLevel.none,
  });

  /// Unique tool identifier (e.g. 'web_search').
  final String name;

  /// Human-readable description shown to the LLM and in UI.
  final String description;

  /// Tool category for grouping (e.g. 'search', 'device', 'memory').
  final String category;

  /// Parameter definitions for this tool.
  final List<ToolArgumentDef> parameters;

  /// Permission requirements for this tool.
  final List<ToolPermissionRequirement> permissionRequirements;

  /// Whether this tool can cause destructive side effects.
  final bool isDangerous;

  /// Whether the user must confirm before this tool runs.
  final bool requiresConfirmation;

  /// Tool version for forward compatibility.
  final String version;

  /// Tags for search/filter in the tool registry.
  final List<String> tags;

  /// Optional icon name for UI representation.
  final String? icon;

  // ── Phase 4 additions ──

  /// Expected output schema (JSON Schema fragment) for result validation.
  final Map<String, dynamic>? outputSchema;

  /// Maximum time to wait for this tool before considering it timed out.
  final Duration timeout;

  /// Retry policy specific to this tool (overrides plan-level policy).
  final RetryPolicy? retryPolicy;

  /// How to verify this tool's results.
  ///
  /// Options: 'has_data', 'contains:X', 'count>N', 'custom:...', or null (no verification).
  final String? verificationStrategy;

  /// Risk level of this tool — determines confirmation requirements.
  final ToolRiskLevel riskLevel;

  /// Whether this tool's risk level requires confirmation.
  bool get needsConfirmation =>
      requiresConfirmation || riskLevel.requiresConfirmation;

  /// Converts to OpenAI function-calling tool schema.
  Map<String, dynamic> toOpenAISchema() {
    final properties = <String, dynamic>{};
    final required = <String>[];

    for (final param in parameters) {
      properties[param.name] = param.toSchemaMap();
      if (param.isRequired) required.add(param.name);
    }

    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': {
          'type': 'object',
          'properties': properties,
          if (required.isNotEmpty) 'required': required,
        },
      },
    };
  }

  @override
  String toString() => 'ToolDefinition($name: $description)';
}
