/// Step 24 — Trigger Normalization Service
///
/// Normalizes trigger payloads into a unified format suitable for
/// the Step 23 orchestration pipeline.
/// FAIL-CLOSED: if normalization fails, the original request is preserved
/// but flagged with an empty user request (which will cause orchestration
/// to deny — FAIL-CLOSED chain).
///
/// The trigger layer is THIN: normalization only transforms the payload
/// into the shape expected by OrchestrationUseCase.execute().
/// It does NOT duplicate agent/security/permission/recovery logic.

import '../../domain/entities/trigger_request.dart';
import '../../domain/value_objects/trigger_type.dart';

class NormalizedTriggerPayload {
  final String userRequest;
  final String locale;
  final bool isVoiceRequest;
  final bool isScreenAction;
  final String requestId;
  final TriggerType originalType;

  const NormalizedTriggerPayload({
    required this.userRequest,
    this.locale = 'ku',
    this.isVoiceRequest = false,
    this.isScreenAction = false,
    required this.requestId,
    required this.originalType,
  });

  @override
  String toString() =>
      'NormalizedTriggerPayload(request: $userRequest, locale: $locale, '
      'voice: $isVoiceRequest, screen: $isScreenAction, id: $requestId)';
}

class TriggerNormalizationService {
  /// Default prompt when no text payload is available.
  /// Kurdish Sorani RTL first.
  static const String _defaultKurdishPrompt =
      'بەکارهێنەری ئاورا، تکایە یارمەتیم بدە';

  /// Normalize a TriggerRequest into a NormalizedTriggerPayload
  /// suitable for OrchestrationUseCase.execute().
  ///
  /// Mapping rules:
  /// - textPayload → userRequest
  /// - isVoiceInput → isVoiceRequest
  /// - TriggerType.notificationAction with action metadata → isScreenAction
  /// - TriggerType.inApp → isScreenAction = true
  /// - locale preserved (default 'ku')
  TriggerRequest normalize(TriggerRequest request) {
    final String userRequest = _extractUserRequest(request);
    final bool isVoiceRequest = request.isVoiceInput;
    final bool isScreenAction = _determineIsScreenAction(request);

    // Create a normalized copy of the request with the extracted payload.
    // The original request is immutable; we return a new instance with
    // the textPayload set to the normalized user request.
    return TriggerRequest(
      requestId: request.requestId,
      triggerType: request.triggerType,
      source: request.source,
      timestamp: request.timestamp,
      textPayload: userRequest,
      isVoiceInput: isVoiceRequest,
      metadata: {
        ...request.metadata,
        'isScreenAction': isScreenAction,
        'normalizedFrom': request.triggerType.name,
      },
      locale: request.locale,
    );
  }

  /// Extract the user request string from the trigger payload.
  /// FAIL-CLOSED: if no text payload, use the Kurdish default prompt.
  String _extractUserRequest(TriggerRequest request) {
    if (request.hasTextPayload) {
      return request.textPayload!.trim();
    }

    // For notification actions, extract action label from metadata.
    if (request.triggerType == TriggerType.notificationAction &&
        request.metadata.containsKey('actionLabel')) {
      final label = request.metadata['actionLabel'];
      if (label is String && label.isNotEmpty) {
        return label.trim();
      }
    }

    // FAIL-CLOSED: no usable text → default prompt (orchestration may deny)
    return _defaultKurdishPrompt;
  }

  /// Determine if this trigger constitutes a screen action.
  bool _determineIsScreenAction(TriggerRequest request) {
    // In-app triggers are always screen actions.
    if (request.triggerType == TriggerType.inApp) {
      return true;
    }

    // Notification actions with screen intent metadata.
    if (request.triggerType == TriggerType.notificationAction &&
        request.metadata.containsKey('isScreenAction')) {
      final val = request.metadata['isScreenAction'];
      return val == true || val == 'true';
    }

    return false;
  }
}
