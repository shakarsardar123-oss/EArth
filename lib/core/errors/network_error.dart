/// Reusable network error model for future API operations.
///
/// Provides a structured error abstraction that Phase 3 can use
/// to implement centralized network handling and retry logic.
enum NetworkErrorType {
  unauthorized,
  rateLimited,
  badRequest,
  forbidden,
  notFound,
  timeout,
  noInternet,
  serverError,
  malformedResponse,
  unknown;

  /// Maps an HTTP status code to a [NetworkErrorType].
  static NetworkErrorType fromStatusCode(int? statusCode) {
    if (statusCode == null) return NetworkErrorType.unknown;
    switch (statusCode) {
      case 400:
        return NetworkErrorType.badRequest;
      case 401:
        return NetworkErrorType.unauthorized;
      case 403:
        return NetworkErrorType.forbidden;
      case 404:
        return NetworkErrorType.notFound;
      case 429:
        return NetworkErrorType.rateLimited;
      default:
        if (statusCode >= 500 && statusCode < 600) {
          return NetworkErrorType.serverError;
        }
        return NetworkErrorType.unknown;
    }
  }
}

/// A structured network error that carries its type, an optional HTTP
/// status code, and a human-readable message.
class NetworkError implements Exception {
  const NetworkError({
    required this.type,
    this.statusCode,
    this.message,
    this.originalError,
    this.stackTrace,
  });

  final NetworkErrorType type;
  final int? statusCode;
  final String? message;
  final Object? originalError;
  final StackTrace? stackTrace;

  /// Convenience factory for creating a [NetworkError] from a status code.
  factory NetworkError.fromStatusCode(
    int? statusCode, {
    String? message,
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    return NetworkError(
      type: NetworkErrorType.fromStatusCode(statusCode),
      statusCode: statusCode,
      message: message,
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  /// Convenience factory for timeout errors.
  factory NetworkError.timeout({String? message}) {
    return NetworkError(
      type: NetworkErrorType.timeout,
      message: message ?? 'Request timed out',
    );
  }

  /// Convenience factory for no-internet errors.
  factory NetworkError.noInternet({String? message}) {
    return NetworkError(
      type: NetworkErrorType.noInternet,
      message: message ?? 'No internet connection',
    );
  }

  /// Convenience factory for malformed response errors.
  factory NetworkError.malformedResponse({
    String? message,
    Object? originalError,
  }) {
    return NetworkError(
      type: NetworkErrorType.malformedResponse,
      message: message ?? 'Malformed response from server',
      originalError: originalError,
    );
  }

  /// Whether this error is retryable.
  bool get isRetryable {
    switch (type) {
      case NetworkErrorType.timeout:
      case NetworkErrorType.noInternet:
      case NetworkErrorType.serverError:
      case NetworkErrorType.rateLimited:
        return true;
      default:
        return false;
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer('NetworkError(')
      ..write('type: $type');
    if (statusCode != null) buffer.write(', statusCode: $statusCode');
    if (message != null) buffer.write(', message: $message');
    buffer.write(')');
    return buffer.toString();
  }
}
