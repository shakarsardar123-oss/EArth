/// api_request.dart
/// AURA Assistant – Step 27: API Reliability & Cost Optimization
///
/// Domain model representing an API request with cost metadata.
library;

/// Priority level for an API request.
enum ApiRequestPriority {
  critical,
  high,
  normal,
  low,
  unknown,
  ;

  /// FAIL-CLOSED: unknown → treated as low.
  bool get isCritical => this == critical;
  bool get isLow => this == low || this == unknown;
}

/// Status of an API request in its lifecycle.
enum ApiRequestStatus {
  pending,
  inFlight,
  completed,
  failed,
  cancelled,
  throttled,
  unknown,
  ;

  bool get isTerminal =>
      this == completed || this == failed || this == cancelled || this == unknown;
  bool get isSuccess => this == completed;
  bool get isDenied =>
      this == failed || this == throttled || this == unknown;
}

/// Domain model for an API request.
class ApiRequest {
  final String requestId;
  final String endpoint;
  final String method;
  final ApiRequestPriority priority;
  final ApiRequestStatus status;
  final int estimatedTokenCount;
  final double estimatedCost;
  final DateTime createdAt;
  final int timeoutMs;
  final int maxRetries;
  final int retryCount;
  final String? correlationId;
  final Map<String, dynamic> metadata;

  const ApiRequest({
    required this.requestId,
    required this.endpoint,
    required this.method,
    this.priority = ApiRequestPriority.normal,
    this.status = ApiRequestStatus.pending,
    this.estimatedTokenCount = 0,
    this.estimatedCost = 0.0,
    required this.createdAt,
    this.timeoutMs = 30000,
    this.maxRetries = 3,
    this.retryCount = 0,
    this.correlationId,
    this.metadata = const {},
  });

  /// FAIL-CLOSED factory: unknown request → lowest priority.
  factory ApiRequest.unknown() => ApiRequest(
        requestId: '__unknown__',
        endpoint: '__unknown__',
        method: '__unknown__',
        priority: ApiRequestPriority.unknown,
        status: ApiRequestStatus.unknown,
        estimatedTokenCount: 0,
        estimatedCost: 0.0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  bool get isUnknown =>
      requestId == '__unknown__' || endpoint == '__unknown__';

  ApiRequest copyWith({
    ApiRequestStatus? status,
    int? retryCount,
    String? correlationId,
  }) =>
      ApiRequest(
        requestId: requestId,
        endpoint: endpoint,
        method: method,
        priority: priority,
        status: status ?? this.status,
        estimatedTokenCount: estimatedTokenCount,
        estimatedCost: estimatedCost,
        createdAt: createdAt,
        timeoutMs: timeoutMs,
        maxRetries: maxRetries,
        retryCount: retryCount ?? this.retryCount,
        correlationId: correlationId ?? this.correlationId,
        metadata: metadata,
      );

  @override
  String toString() =>
      'ApiRequest($requestId, $endpoint, $method, priority=$priority, status=$status)';
}
