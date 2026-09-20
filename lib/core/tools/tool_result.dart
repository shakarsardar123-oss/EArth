import '../../core/errors/result.dart';
/// Represents the result of a tool execution.
///
/// A tool can either succeed with a [data] payload or fail with an
/// [errorMessage] and optional [errorCode].
class ToolResult {
  const ToolResult.success(this.data)
      : errorMessage = null,
        errorCode = null,
        isSuccess = true;

  const ToolResult.failure(this.errorMessage, {this.errorCode})
      : data = null,
        isSuccess = false;

  final dynamic data;
  final String? errorMessage;
  final String? errorCode;
  final bool isSuccess;

  /// Convenience getter — throws if this is a failure.
  dynamic get dataOrThrow {
    if (!isSuccess) {
      throw ToolResultException(errorMessage ?? 'Unknown tool error', code: errorCode);
    }
    return data;
  }

  @override
  String toString() {
    if (isSuccess) return 'ToolResult.success($data)';
    return 'ToolResult.failure($errorMessage, code: $errorCode)';
  }
}

/// Exception thrown when accessing [ToolResult.dataOrThrow] on a failure.
class ToolResultException implements Exception {
  const ToolResultException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'ToolResultException: $message (code: $code)';
}
