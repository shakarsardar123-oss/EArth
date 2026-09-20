/// Exception thrown by AI providers when a request fails.
class AIProviderException implements Exception {
  const AIProviderException({
    required this.message,
    this.statusCode,
    this.errorCode,
    this.providerId,
    this.originalError,
  });

  final String message;
  final int? statusCode;
  final String? errorCode;
  final String? providerId;
  final Object? originalError;

  /// Authentication failure (401/403).
  bool get isAuthError => statusCode == 401 || statusCode == 403;

  /// Rate limit hit (429).
  bool get isRateLimit => statusCode == 429;

  /// Server error (5xx).
  bool get isServerError => statusCode != null && statusCode! >= 500;

  /// Network error (no status code).
  bool get isNetworkError => statusCode == null && originalError != null;

  /// Model-not-found / unsupported-model failure.
  ///
  /// Detects the common shapes across providers:
  /// - HTTP 404
  /// - structured error codes (`NOT_FOUND`, `model_not_found`)
  /// - human messages mentioning an unknown/unsupported/deprecated model
  ///
  /// Used by AUTO mode to trigger a single rediscover-and-retry. It is
  /// deliberately conservative so that auth (401/403) and rate-limit
  /// (429) errors never match.
  bool get isModelNotFound {
    if (isAuthError || isRateLimit) return false;
    if (statusCode == 404) return true;
    final code = errorCode?.toLowerCase() ?? '';
    if (code == 'not_found' ||
        code == 'model_not_found' ||
        code == 'model_not_available') {
      return true;
    }
    final msg = message.toLowerCase();
    if (!msg.contains('model')) return false;
    return msg.contains('not found') ||
        msg.contains('not supported') ||
        msg.contains('does not exist') ||
        msg.contains('is not available') ||
        msg.contains('unsupported') ||
        msg.contains('deprecated') ||
        msg.contains('unknown model');
  }

  @override
  String toString() =>
      'AIProviderException($providerId, $statusCode, $errorCode): $message';
}
