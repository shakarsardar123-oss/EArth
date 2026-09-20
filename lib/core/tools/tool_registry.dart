import 'tool.dart';
import 'tool_definition.dart';

/// Registry that holds all available tools and provides lookup by name or category.
///
/// Phase 4 enhancements:
/// - Tool allowlist for security
/// - Argument sanitization
/// - Risk-level filtering
class ToolRegistry {
  final Map<String, Tool> _tools = {};

  /// If set, only these tools are allowed to execute.
  /// Null = all registered tools are allowed.
  Set<String>? _allowlist;

  /// Whether to enforce the allowlist.
  bool _enforceAllowlist = false;

  /// Registers a tool. Overwrites if a tool with the same name already exists.
  void register(Tool tool) {
    _tools[tool.name] = tool;
  }

  /// Unregisters a tool by name.
  void unregister(String name) {
    _tools.remove(name);
  }

  /// Returns the tool with [name], or null if not found.
  Tool? get(String name) => _tools[name];

  /// Returns the tool with [name], or throws if not found.
  Tool getOrThrow(String name) {
    final tool = _tools[name];
    if (tool == null) {
      throw StateError('Tool not found: $name');
    }
    return tool;
  }

  /// Whether a tool with [name] is registered.
  bool has(String name) => _tools.containsKey(name);

  /// Whether a tool with [name] is allowed by the allowlist.
  bool isAllowed(String name) {
    if (!_enforceAllowlist) return true;
    if (_allowlist == null) return true;
    return _allowlist!.contains(name);
  }

  /// Set the tool allowlist. Only these tools will be allowed to execute.
  void setAllowlist(Set<String> allowed) {
    _allowlist = Set<String>.from(allowed);
    _enforceAllowlist = true;
  }

  /// Remove allowlist restrictions — all tools are allowed.
  void clearAllowlist() {
    _allowlist = null;
    _enforceAllowlist = false;
  }

  /// Enable allowlist enforcement with the current set.
  void enforceAllowlist() => _enforceAllowlist = true;

  /// Disable allowlist enforcement.
  void disableAllowlist() => _enforceAllowlist = false;

  /// All registered tools.
  List<Tool> get all => List.unmodifiable(_tools.values);

  /// All registered tool definitions.
  List<ToolDefinition> get allDefinitions =>
      _tools.values.map((t) => t.definition).toList();

  /// All tools that are currently allowed (registered + allowlisted).
  List<Tool> get allowedTools =>
      _tools.values.where((t) => isAllowed(t.name)).toList();

  /// Returns tools filtered by category.
  List<Tool> getByCategory(String category) =>
      _tools.values.where((t) => t.definition.category == category).toList();

  /// Returns tools that have any of the given tags.
  List<Tool> getByTags(List<String> tags) => _tools.values
      .where((t) => t.definition.tags.any((tag) => tags.contains(tag)))
      .toList();

  /// Returns tools that require user confirmation before execution.
  List<Tool> get requiringConfirmation =>
      _tools.values.where((t) => t.definition.needsConfirmation).toList();

  /// Returns tools that are marked as dangerous.
  List<Tool> get dangerous =>
      _tools.values.where((t) => t.definition.isDangerous).toList();

  /// Returns all tool definitions in OpenAI function-calling schema format.
  List<Map<String, dynamic>> get openAISchemas =>
      allDefinitions.map((d) => d.toOpenAISchema()).toList();

  /// Number of registered tools.
  int get count => _tools.length;

  /// Clears all registered tools.
  void clear() => _tools.clear();

  /// Sanitize tool arguments — remove potential injection vectors.
  ///
  /// Strips null bytes, trims whitespace, and checks for suspicious patterns.
  Map<String, dynamic> sanitizeArguments(Map<String, dynamic> args) {
    final sanitized = <String, dynamic>{};
    args.forEach((key, value) {
      sanitized[key] = _sanitizeValue(value);
    });
    return sanitized;
  }

  dynamic _sanitizeValue(dynamic value) {
    if (value is String) {
      // Remove null bytes and trim.
      var cleaned = value.replaceAll('\x00', '').trim();
      // Remove obvious injection patterns.
      cleaned = cleaned.replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '');
      cleaned = cleaned.replaceAll(RegExp(r'javascript:', caseSensitive: false), '');
      cleaned = cleaned.replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '');
      return cleaned;
    }
    if (value is Map) {
      return sanitizeArguments(Map<String, dynamic>.from(value));
    }
    if (value is List) {
      return value.map((v) => _sanitizeValue(v)).toList();
    }
    return value;
  }
}
