import 'tool_arguments.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Abstract base class for all AURA tools.
///
/// Each tool must provide a [definition] and implement [execute].
/// Tools are registered in the [ToolRegistry] and invoked by the [AgentEngine].
abstract class Tool {
  /// The definition describing this tool's metadata and parameters.
  ToolDefinition get definition;

  /// Execute the tool with the given [arguments].
  ///
  /// Returns a [ToolResult] indicating success or failure.
  /// Implementations must be safe to call from an isolate or async context.
  Future<ToolResult> execute(ToolArguments arguments);

  /// Optional: validate arguments before execution.
  ///
  /// Return null if valid, or an error message string if invalid.
  String? validateArguments(ToolArguments arguments) => null;

  /// Convenience getter for the tool's name.
  String get name => definition.name;

  /// Convenience getter for the tool's description.
  String get description => definition.description;

  @override
  String toString() => 'Tool($name)';
}
