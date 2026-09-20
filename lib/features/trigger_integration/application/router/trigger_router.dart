/// Step 24 — Trigger Router
///
/// Routes incoming triggers to the appropriate handler based on TriggerType.
/// FAIL-CLOSED: unknown types are routed to the deny handler.
/// UNKNOWN = DENY, ERROR = DENY, UNAVAILABLE = DENY.

import '../../domain/value_objects/trigger_type.dart';
import '../../domain/entities/trigger_request.dart';
import '../../domain/entities/trigger_result.dart';

/// Handler function signature for a specific trigger type.
typedef TriggerTypeHandler = Future<TriggerResult> Function(
  TriggerRequest request,
);

class TriggerRouter {
  final Map<TriggerType, TriggerTypeHandler> _handlers;
  final TriggerTypeHandler _denyHandler;

  TriggerRouter({
    required Map<TriggerType, TriggerTypeHandler> handlers,
    required TriggerTypeHandler denyHandler,
  })  : _handlers = handlers,
        _denyHandler = denyHandler;

  /// Route a trigger request to the appropriate handler.
  /// FAIL-CLOSED: unknown types → deny handler.
  /// If the mapped handler throws, catch and route to deny handler.
  Future<TriggerResult> route(TriggerRequest request) async {
    final TriggerType type = request.triggerType;

    // FAIL-CLOSED: unknown trigger types are always denied.
    if (type == TriggerType.unknown || !type.isAuthorizable) {
      return _denyHandler(request);
    }

    final handler = _handlers[type];
    if (handler == null) {
      // FAIL-CLOSED: no handler registered → deny.
      return _denyHandler(request);
    }

    try {
      return await handler(request);
    } catch (e) {
      // FAIL-CLOSED: handler error → deny.
      return _denyHandler(request);
    }
  }

  /// Check if a handler is registered for the given type.
  bool hasHandler(TriggerType type) => _handlers.containsKey(type);

  /// List all registered trigger types.
  List<TriggerType> get registeredTypes => _handlers.keys.toList();
}
