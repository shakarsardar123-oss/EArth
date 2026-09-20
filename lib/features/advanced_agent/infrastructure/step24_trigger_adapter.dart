/// step24_trigger_adapter.dart
/// AURA Assistant – Step 25: Infrastructure adapter for Step 24 Triggers.
///
/// Adapts Step 24's TriggerAuthorizationRepository contract to Step 25's
/// internal TriggerRepository.  Provides a bidirectional type mapping so
/// Step 24 trigger types (quickSettings, homeLongPress, …) are correctly
/// translated into Step 25 trigger types (voiceCommand, gesture, …).
///
/// FAIL-CLOSED: unknown/invalid triggers → NEVER authorize.
library;

import '../../trigger_integration/domain/repositories/trigger_authorization_repository.dart';
import '../../trigger_integration/domain/entities/trigger_request.dart' as s24;
import '../../trigger_integration/domain/value_objects/trigger_type.dart' as s24;
import '../domain/repositories/trigger_repository.dart';

/// Bidirectional mapping between Step 24 and Step 25 TriggerType values.
///
/// Design decisions:
///   quickSettings       → event     (UI toggle = discrete event)
///   assistantLongPress  → gesture   (long-press = gesture)
///   homeLongPress       → gesture   (long-press = gesture)
///   notificationAction  → event    (notification tap = discrete event)
///   inApp               → event    (in-app trigger = discrete event)
///   unknown             → unknown  (FAIL-CLOSED passthrough)
class TriggerTypeMapper {
  /// Step 24 → Step 25
  static TriggerType toStep25(s24.TriggerType type) {
    switch (type) {
      case s24.TriggerType.quickSettings:
        return TriggerType.event;
      case s24.TriggerType.assistantLongPress:
        return TriggerType.gesture;
      case s24.TriggerType.homeLongPress:
        return TriggerType.gesture;
      case s24.TriggerType.notificationAction:
        return TriggerType.event;
      case s24.TriggerType.inApp:
        return TriggerType.event;
      case s24.TriggerType.unknown:
        return TriggerType.unknown;
    }
  }

  /// Step 25 → Step 24
  static s24.TriggerType toStep24(TriggerType type) {
    switch (type) {
      case TriggerType.voiceCommand:
        return s24.TriggerType.unknown; // no Step 24 equivalent
      case TriggerType.schedule:
        return s24.TriggerType.unknown; // no Step 24 equivalent
      case TriggerType.event:
        return s24.TriggerType.notificationAction; // closest match
      case TriggerType.proximity:
        return s24.TriggerType.unknown; // no Step 24 equivalent
      case TriggerType.gesture:
        return s24.TriggerType.homeLongPress; // closest match
      case TriggerType.unknown:
        return s24.TriggerType.unknown;
    }
  }
}

/// Adapter bridging Step 24 Triggers to Step 25's TriggerRepository.
///
/// NOW correctly implements Step 24's [TriggerAuthorizationRepository]
/// (not Step 25's TriggerRepository), translating types through
/// [TriggerTypeMapper].
///
/// FAIL-CLOSED rules:
///   - s24.TriggerType.unknown → NEVER authorize (always denied)
///   - Adapter unavailable → denied verdict
///   - Invalid/missing request → denied verdict
class Step24TriggerAdapter implements TriggerAuthorizationRepository {
  /// Internal Step 25 repository to delegate to.
  final TriggerRepository _inner;

  /// Whether the adapter is currently available.
  bool _available;

  /// Step 24 types this adapter permits (populated by wiring).
  final Set<s24.TriggerType> _permittedStep24Types;

  Step24TriggerAdapter({
    required TriggerRepository inner,
    bool available = true,
    Set<s24.TriggerType>? permittedStep24Types,
  })  : _inner = inner,
        _available = available,
        _permittedStep24Types = permittedStep24Types ??
            {
              s24.TriggerType.quickSettings,
              s24.TriggerType.assistantLongPress,
              s24.TriggerType.homeLongPress,
              s24.TriggerType.notificationAction,
              s24.TriggerType.inApp,
            };

  @override
  Future<TriggerAuthorizationVerdict> authorize(
    s24.TriggerRequest request,
  ) async {
    // FAIL-CLOSED: unavailable → denied
    if (!_available) {
      return TriggerAuthorizationVerdict.denied(
        reason: 'Trigger service unavailable — failing closed.',
      );
    }

    // FAIL-CLOSED: unknown trigger type → ALWAYS denied
    if (request.triggerType == s24.TriggerType.unknown) {
      return TriggerAuthorizationVerdict.denied(
        reason: 'Unknown trigger type — never authorized.',
      );
    }

    // FAIL-CLOSED: type not in permitted set → denied
    if (!_permittedStep24Types.contains(request.triggerType)) {
      return TriggerAuthorizationVerdict.denied(
        reason: 'Trigger type ${request.triggerType.name} not permitted.',
      );
    }

    // FAIL-CLOSED: missing request ID → denied
    if (request.requestId.isEmpty) {
      return TriggerAuthorizationVerdict.denied(
        reason: 'Missing trigger ID — failing closed.',
      );
    }

    // Map Step 24 request → Step 25 request and delegate.
    final s25Type = TriggerTypeMapper.toStep25(request.triggerType);
    final s25Request = TriggerRequest(
      id: request.requestId,
      type: s25Type,
      payload: {
        'source': request.source,
        'textPayload': request.textPayload,
        'isVoiceInput': request.isVoiceInput,
        'locale': request.locale,
        ...request.metadata,
      },
      timestamp: request.timestamp,
    );

    // Delegate to Step 25 repository.
    final s25Verdict = await _inner.authorize(s25Request);

    // Map Step 25 verdict → Step 24 verdict.
    if (s25Verdict.authorized) {
      return TriggerAuthorizationVerdict.authorized(
        policyId: 'step25-delegation',
      );
    } else {
      return TriggerAuthorizationVerdict.denied(
        reason: s25Verdict.reason ?? 'Denied by Step 25 trigger repository.',
      );
    }
  }

  @override
  Future<bool> isAvailable() async => _available && _inner.isAvailable();

  @override
  Future<bool> isTriggerTypePermitted(s24.TriggerType type) async {
    // FAIL-CLOSED: unknown → NEVER permitted
    if (type == s24.TriggerType.unknown) return false;

    if (!_permittedStep24Types.contains(type)) return false;

    // Also check with Step 25's repository using mapped type.
    final s25Type = TriggerTypeMapper.toStep25(type);
    return _inner.isTriggerTypePermitted(s25Type);
  }

  /// Add a permitted Step 24 type (for wiring/testing).
  void addPermittedStep24Type(s24.TriggerType type) =>
      _permittedStep24Types.add(type);

  /// Mark adapter as available (for wiring/testing).
  void setAvailable(bool available) => _available = available;
}
