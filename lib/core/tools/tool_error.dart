/// Error codes for tool execution failures.
enum ToolErrorCode {
  /// The tool could not be found in the registry.
  notFound,

  /// The arguments passed to the tool are invalid.
  invalidArguments,

  /// The tool execution timed out.
  timeout,

  /// A required permission was not granted.
  permissionDenied,

  /// The tool encountered an internal error.
  internalError,

  /// The tool is not available on the current platform.
  platformUnsupported,

  /// Network error during tool execution.
  networkError,
}

/// Represents an error that occurred during tool execution.
class ToolError {
  const ToolError({
    required this.code,
    required this.message,
    this.details,
  this.originalError,
    this.stackTrace,
  });

  final ToolErrorCode code;
  final String message;
  final Map<String, dynamic>? details;
  final Object? originalError;
  final StackTrace? stackTrace;

  /// Creates a [ToolError] from a caught exception.
  factory ToolError.fromException(
    Object error, [
    StackTrace? stackTrace,
  ]) {
    return ToolError(
      code: ToolErrorCode.internalError,
      message: error.toString(),
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  @override
  String toString() => 'ToolError($code): $message';
}
