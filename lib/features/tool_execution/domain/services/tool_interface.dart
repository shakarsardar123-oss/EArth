/// tool_interface.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Abstract Tool interface — the contract every tool executor must implement.
/// KEY FIXES from Step 22:
///   - riskLevel is String (NOT ToolRiskLevel enum)
///   - cancel() returns bool (NOT void)
///   - validate() returns ToolInput (using canonical factories)
///   - All ToolOutput factories require toolId
///
/// FAIL CLOSED: default implementations deny.
library;

import '../models/tool_input.dart';
import '../models/tool_output.dart';
import '../models/tool_execution_context.dart';

/// Tool categories
enum ToolCategory {
  device,
  screen,
  voice,
  memory,
  vision,
  media,
  assistant,
  communication,
  navigation,
  system,
  unknown,
}

/// Abstract Tool — every executor must extend this.
abstract class Tool {
  String get id;
  String get name;
  ToolCategory get category;
  String get description;
  String get version;
  List<String> get requiredPermissions;

  /// Risk level as String — NOT an enum.
  /// Valid values: 'low', 'medium', 'high', 'critical'.
  String get riskLevel;

  bool get requiresConfirmation;
  bool get supportsOffline;
  bool get isVoiceSafe;
  int get defaultTimeoutMs;
  bool get isExecuting;

  /// Execute the tool with validated input and execution context.
  /// Returns ToolOutput with toolId as first parameter.
  Future<ToolOutput> execute(ToolInput input, ToolExecutionContext context);

  /// Validate input params and return a ToolInput (valid or invalid).
  /// Uses ToolInput.valid() or ToolInput.invalid() factories.
  ToolInput validate(Map<String, dynamic> params);

  /// Human-readable description of what this tool does.
  String describe();

  /// Cancel current execution.
  /// Returns true if cancellation succeeded, false otherwise.
  bool cancel();
}
