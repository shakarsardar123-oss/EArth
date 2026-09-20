/// Step 24 — Trigger Request
///
/// Immutable domain entity representing an incoming trigger request.
/// Contains all metadata needed to validate, authorize, and route the trigger.
/// FAIL-CLOSED: default values are deny-oriented.

import '../value_objects/trigger_type.dart';

class TriggerRequest {
  /// Unique identifier for this trigger request.
  final String requestId;

  /// The type of trigger that originated this request.
  final TriggerType triggerType;

  /// The source identifier (e.g., tile ID, package name).
  final String source;

  /// Timestamp when the trigger was received.
  final DateTime timestamp;

  /// Optional text payload (voice transcript or typed text).
  final String? textPayload;

  /// Optional voice input flag.
  final bool isVoiceInput;

  /// Additional metadata from the trigger source.
  final Map<String, dynamic> metadata;

  /// Locale for localization — Kurdish Sorani RTL first: 'ku'.
  final String locale;

  const TriggerRequest({
    required this.requestId,
    required this.triggerType,
    required this.source,
    required this.timestamp,
    this.textPayload,
    this.isVoiceInput = false,
    this.metadata = const {},
    this.locale = 'ku',
  });

  /// FAIL-CLOSED: factory for unknown/invalid trigger requests.
  factory TriggerRequest.unknown({
    required String requestId,
    String source = 'unknown',
  }) =>
      TriggerRequest(
        requestId: requestId,
        triggerType: TriggerType.unknown,
        source: source,
        timestamp: DateTime.now(),
        locale: 'ku',
      );

  /// Whether this trigger request has an authorizable type.
  /// FAIL-CLOSED: [TriggerType.unknown] is never authorizable.
  bool get isAuthorizable => triggerType.isAuthorizable;

  /// Whether the request has a usable text payload.
  bool get hasTextPayload =>
      textPayload != null && textPayload!.isNotEmpty;

  @override
  String toString() =>
      'TriggerRequest(requestId: $requestId, type: $triggerType, '
      'source: $source, voice: $isVoiceInput, locale: $locale)';
}
