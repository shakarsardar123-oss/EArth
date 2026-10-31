/// semantic_memory_adapter.dart
/// AURA Assistant – Step 17: Semantic Memory
///
/// Agent tool adapter for semantic memory operations.
/// Provides remember/recall/forget/update/list tools
/// that the agent engine can invoke.
///
/// Follows the FeaturePermissionAdapter pattern:
///   - Abstract base class with tool definitions
///   - Concrete implementation wired to MemoryManager
///
/// Kurdish-first, local-first, privacy-conscious.
library;

import '../domain/models/memory_type.dart';
import '../application/memory_manager.dart';
import '../application/memory_policy.dart';
import '../../../core/errors/result.dart';

/// A tool invocation result returned to the agent engine.
class MemoryToolResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  const MemoryToolResult.success(this.message, {this.data})
      : success = true;
  const MemoryToolResult.failure(this.message, {this.data})
      : success = false;

  Map<String, dynamic> toJson() => {
        'success': success,
        'message': message,
        if (data != null) 'data': data,
      };
}

/// Tool parameter definition for agent tool registration.
class MemoryToolParam {
  final String name;
  final String description;
  final bool required;
  final String? defaultValue;

  const MemoryToolParam({
    required this.name,
    required this.description,
    this.required = true,
    this.defaultValue,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'required': required,
        if (defaultValue != null) 'default': defaultValue,
      };
}

/// Tool definition for agent tool registration.
class MemoryToolDef {
  final String name;
  final String description;
  final List<MemoryToolParam> parameters;

  const MemoryToolDef({
    required this.name,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'parameters': parameters.map((p) => p.toJson()).toList(),
      };
}

/// Abstract adapter base class for semantic memory agent tools.
///
/// Defines the tool interface that the agent engine uses
/// to interact with semantic memory.
abstract class SemanticMemoryAdapter {
  // ─── Tool name constants ──────────────────────────────────────────
  static const String rememberTool = 'semantic_memory_remember';
  static const String recallTool = 'semantic_memory_recall';
  static const String forgetTool = 'semantic_memory_forget';
  static const String updateTool = 'semantic_memory_update';
  static const String listTool = 'semantic_memory_list';

  // ─── Tool definitions ────────────────────────────────────────────

  /// Definition for the remember tool.
  static MemoryToolDef get rememberDefinition => const MemoryToolDef(
        name: rememberTool,
        description:
            'Store a new piece of information in the user\'s semantic memory. '
            'Use this when the user explicitly asks you to remember something, '
            'or shares a preference, fact, or instruction worth keeping.',
        parameters: [
          MemoryToolParam(
            name: 'content',
            description: 'The information to remember.',
          ),
          MemoryToolParam(
            name: 'type',
            description: 'Type of memory: userPreference, personalFact, '
                'conversation, task, project, device, location, instruction, other.',
            required: false,
            defaultValue: 'conversation',
          ),
          MemoryToolParam(
            name: 'importance',
            description: 'Importance score 0.0-1.0.',
            required: false,
            defaultValue: '0.5',
          ),
        ],
      );

  /// Definition for the recall tool.
  static MemoryToolDef get recallDefinition => const MemoryToolDef(
        name: recallTool,
        description:
            'Search the user\'s semantic memory for information relevant '
            'to a query. Use this when the user asks about their preferences, '
            'past conversations, or previously stored information.',
        parameters: [
          MemoryToolParam(
            name: 'query',
            description: 'The search query.',
          ),
          MemoryToolParam(
            name: 'limit',
            description: 'Max results to return.',
            required: false,
            defaultValue: '5',
          ),
        ],
      );

  /// Definition for the forget tool.
  static MemoryToolDef get forgetDefinition => const MemoryToolDef(
        name: forgetTool,
        description:
            'Remove a specific memory from the user\'s semantic memory. '
            'Use this when the user explicitly asks you to forget something.',
        parameters: [
          MemoryToolParam(
            name: 'id',
            description: 'The ID of the memory to forget.',
          ),
        ],
      );

  /// Definition for the update tool.
  static MemoryToolDef get updateDefinition => const MemoryToolDef(
        name: updateTool,
        description:
            'Update an existing memory in the user\'s semantic memory. '
            'Use this when the user wants to correct or modify previously '
            'stored information.',
        parameters: [
          MemoryToolParam(
            name: 'id',
            description: 'The ID of the memory to update.',
          ),
          MemoryToolParam(
            name: 'content',
            description: 'The new content for the memory.',
          ),
        ],
      );

  /// Definition for the list tool.
  static MemoryToolDef get listDefinition => const MemoryToolDef(
        name: listTool,
        description:
            'List all memories or filter by type. Use this when the user '
            'wants to see what information is stored in their semantic memory.',
        parameters: [
          MemoryToolParam(
            name: 'type',
            description: 'Optional type filter: userPreference, personalFact, '
                'conversation, task, project, device, location, instruction, other.',
            required: false,
          ),
        ],
      );

  /// All tool definitions for registration.
  static List<MemoryToolDef> get allDefinitions => [
        rememberDefinition,
        recallDefinition,
        forgetDefinition,
        updateDefinition,
        listDefinition,
      ];

  // ─── Tool execution ──────────────────────────────────────────────

  /// Execute a named tool with the given arguments.
  Future<MemoryToolResult> execute({
    required String toolName,
    required Map<String, dynamic> arguments,
  });
}

/// Concrete implementation of the semantic memory adapter.
///
/// Delegates tool execution to [MemoryManager] and [MemoryPolicy].
class SemanticMemoryAdapterImpl implements SemanticMemoryAdapter {
  final MemoryManager _manager;
  final MemoryPolicy _policy;

  SemanticMemoryAdapterImpl({
    required MemoryManager manager,
    MemoryPolicy? policy,
  })  : _manager = manager,
        _policy = policy ?? MemoryPolicy();

  @override
  Future<MemoryToolResult> execute({
    required String toolName,
    required Map<String, dynamic> arguments,
  }) async {
    switch (toolName) {
      case SemanticMemoryAdapter.rememberTool:
        return _executeRemember(arguments);
      case SemanticMemoryAdapter.recallTool:
        return _executeRecall(arguments);
      case SemanticMemoryAdapter.forgetTool:
        return _executeForget(arguments);
      case SemanticMemoryAdapter.updateTool:
        return _executeUpdate(arguments);
      case SemanticMemoryAdapter.listTool:
        return _executeList(arguments);
      default:
        return MemoryToolResult.failure('Unknown tool: $toolName');
    }
  }

  // ─── Private tool executors ──────────────────────────────────────

  Future<MemoryToolResult> _executeRemember(Map<String, dynamic> args) async {
    final content = args['content'] as String?;
    if (content == null || content.isEmpty) {
      return const MemoryToolResult.failure('Content is required.');
    }

    // Check policy.
    final check = _policy.check(content);
    if (check.isSensitive) {
      return MemoryToolResult.failure(
        'Cannot remember sensitive information: ${check.reason}',
      );
    }

    final typeStr = args['type'] as String? ?? 'conversation';
    final type = MemoryType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => MemoryType.conversation,
    );

    final importanceStr = args['importance'] as String? ?? '0.5';
    final importance = double.tryParse(importanceStr) ?? 0.5;

    final result = await _manager.remember(
      content: content,
      type: type,
      importance: importance,
      source: 'agent_tool',
    );

    if (result.isError) {
      return MemoryToolResult.failure(
        'Failed to remember: ${result.error!.detail}',
      );
    }

    return MemoryToolResult.success(
      'Remembered: $content',
      data: {'id': result.value!},
    );
  }

  Future<MemoryToolResult> _executeRecall(Map<String, dynamic> args) async {
    final query = args['query'] as String?;
    if (query == null || query.isEmpty) {
      return const MemoryToolResult.failure('Query is required.');
    }

    final limitStr = args['limit'] as String? ?? '5';
    final limit = int.tryParse(limitStr) ?? 5;

    final result = await _manager.recall(
      query: query,
      limit: limit,
    );

    if (result.isError) {
      return MemoryToolResult.failure(
        'Failed to recall: ${result.error!.detail}',
      );
    }

    final memories = result.value!;
    if (memories.isEmpty) {
      return const MemoryToolResult.success('No relevant memories found.');
    }

    final items = memories
        .map((m) => {'id': m.id, 'type': m.memoryType.name, 'content': m.content})
        .toList();

    return MemoryToolResult.success(
      'Found ${memories.length} relevant memories.',
      data: {'memories': items},
    );
  }

  Future<MemoryToolResult> _executeForget(Map<String, dynamic> args) async {
    final id = args['id'] as String?;
    if (id == null || id.isEmpty) {
      return const MemoryToolResult.failure('Memory ID is required.');
    }

    final result = await _manager.forget(id);

    if (result.isError) {
      return MemoryToolResult.failure(
        'Failed to forget: ${result.error!.detail}',
      );
    }

    return const MemoryToolResult.success('Memory forgotten.');
  }

  Future<MemoryToolResult> _executeUpdate(Map<String, dynamic> args) async {
    final id = args['id'] as String?;
    final content = args['content'] as String?;

    if (id == null || id.isEmpty) {
      return const MemoryToolResult.failure('Memory ID is required.');
    }
    if (content == null || content.isEmpty) {
      return const MemoryToolResult.failure('Content is required.');
    }

    // Check policy on new content.
    final check = _policy.check(content);
    if (check.isSensitive) {
      return MemoryToolResult.failure(
        'Cannot store sensitive information: ${check.reason}',
      );
    }

    final result = await _manager.update(id: id, content: content);

    if (result.isError) {
      return MemoryToolResult.failure(
        'Failed to update: ${result.error!.detail}',
      );
    }

    return const MemoryToolResult.success('Memory updated.');
  }

  Future<MemoryToolResult> _executeList(Map<String, dynamic> args) async {
    final typeStr = args['type'] as String?;
    MemoryType? type;
    if (typeStr != null) {
      type = MemoryType.values.firstWhere(
        (t) => t.name == typeStr,
        orElse: () => MemoryType.other,
      );
    }

    final result = await _manager.list(type: type);

    if (result.isError) {
      return MemoryToolResult.failure(
        'Failed to list: ${result.error!.detail}',
      );
    }

    final memories = result.value!;
    final items = memories
        .map((m) => {
              'id': m.id,
              'type': m.memoryType.name,
              'content': m.content,
              'importance': m.importance,
              'active': m.isActive,
            })
        .toList();

    return MemoryToolResult.success(
      'Found ${memories.length} memories.',
      data: {'memories': items, 'count': memories.length},
    );
  }
}
