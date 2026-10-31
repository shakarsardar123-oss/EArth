/// api_request_id.dart
/// AURA Assistant – Step 27: API Reliability & Cost Optimization
///
/// Value object identifying an API request.
library;

class ApiRequestId {
  final String value;

  const ApiRequestId(this.value);

  static const unknown = ApiRequestId('__unknown__');

  bool get isUnknown => value == '__unknown__' || value.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiRequestId && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ApiRequestId($value)';
}
