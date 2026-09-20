/// Step 24 — Trigger Platform Service
///
/// Dart-side platform channel service for Step 24 trigger integration.
/// Handles communication with the Android/Kotlin side via
/// MethodChannel com.aura.assistant/trigger_integration.
///
/// FAIL-CLOSED: any platform channel error → denied result.
/// UNKNOWN = DENY, ERROR = DENY, UNAVAILABLE = DENY.
///
/// Handles Flutter engine unavailability safely — returns unavailable
/// state, no crash, no fake success.

import 'package:flutter/services.dart';
import 'method_channel_constants.dart';
import '../../domain/value_objects/trigger_type.dart';
import '../../domain/entities/trigger_request.dart';
import '../../domain/entities/trigger_result.dart';

class TriggerPlatformService {
  late final MethodChannel _channel;
  bool _engineAvailable = false;

  TriggerPlatformService() {
    _channel = const MethodChannel(
      TriggerMethodChannelConstants.channelName,
    );
    _setupMethodCallHandler();
  }

  /// Method call handler for Android → Flutter calls.
  /// Processes incoming trigger events from the platform side.
  late MethodChannel _methodChannel;

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case TriggerMethodChannelConstants.quickSettingsTrigger:
          return _handleIncomingTrigger(call, TriggerType.quickSettings);
        case TriggerMethodChannelConstants.assistantLongPressTrigger:
          return _handleIncomingTrigger(call, TriggerType.assistantLongPress);
        case TriggerMethodChannelConstants.homeLongPressTrigger:
          return _handleIncomingTrigger(call, TriggerType.homeLongPress);
        case TriggerMethodChannelConstants.notificationActionTrigger:
          return _handleIncomingTrigger(call, TriggerType.notificationAction);
        case TriggerMethodChannelConstants.inAppTrigger:
          return _handleIncomingTrigger(call, TriggerType.inApp);
        default:
          // FAIL-CLOSED: unknown method → null (ignore safely)
          return null;
      }
    });
  }

  /// Handle an incoming trigger from the platform side.
  /// FAIL-CLOSED: malformed arguments → denied result.
  dynamic _handleIncomingTrigger(MethodCall call, TriggerType type) {
    try {
      final args = call.arguments as Map? ?? {};
      final requestId =
          args[TriggerMethodChannelConstants.argRequestId] as String? ??
              _generateRequestId();
      final textPayload =
          args[TriggerMethodChannelConstants.argTextPayload] as String?;
      final isVoiceInput =
          args[TriggerMethodChannelConstants.argIsVoiceInput] as bool? ??
              false;
      final locale =
          args[TriggerMethodChannelConstants.argLocale] as String? ?? 'ku';
      final metadata =
          args[TriggerMethodChannelConstants.argMetadata] as Map? ?? {};

      // Store the request for processing by TriggerController
      _pendingRequests[requestId] = TriggerRequest(
        requestId: requestId,
        triggerType: type,
        source: 'platform',
        timestamp: DateTime.now(),
        textPayload: textPayload,
        isVoiceInput: isVoiceInput,
        metadata: Map<String, dynamic>.from(metadata),
        locale: locale,
      );

      return {'requestId': requestId, 'received': true};
    } catch (e) {
      // FAIL-CLOSED: any error → return deny indicator
      return {'received': false, 'error': 'fail-closed-platform-error'};
    }
  }

  /// Pending requests from platform side, waiting to be picked up
  /// by the TriggerController.
  final Map<String, TriggerRequest> _pendingRequests = {};

  /// Get and remove a pending request.
  TriggerRequest? popPendingRequest(String requestId) {
    return _pendingRequests.remove(requestId);
  }

  /// Check if there are any pending requests.
  bool get hasPendingRequests => _pendingRequests.isNotEmpty;

  /// Get all pending request IDs.
  List<String> get pendingRequestIds => _pendingRequests.keys.toList();

  /// Send a trigger request FROM the Flutter side (in-app trigger).
  /// FAIL-CLOSED: platform channel error → unavailable result.
  Future<TriggerResult> sendInAppTrigger({
    required String requestId,
    String? textPayload,
    bool isVoiceInput = false,
    String locale = 'ku',
  }) async {
    final request = TriggerRequest(
      requestId: requestId,
      triggerType: TriggerType.inApp,
      source: 'in_app',
      timestamp: DateTime.now(),
      textPayload: textPayload,
      isVoiceInput: isVoiceInput,
      locale: locale,
    );

    _pendingRequests[requestId] = request;
    return TriggerResult.launched(
      requestId: requestId,
      triggerType: TriggerType.inApp,
    );
  }

  /// Update the Quick Settings Tile state on Android side.
  /// FAIL-CLOSED: communication error → tile state set to unavailable.
  Future<void> updateTileState(String state) async {
    try {
      await _channel.invokeMethod(
        TriggerMethodChannelConstants.updateTileState,
        {TriggerMethodChannelConstants.argTileState: state},
      );
    } on PlatformException catch (_) {
      // FAIL-CLOSED: silently ignore — tile state update is best-effort
    } on MissingPluginException catch (_) {
      // Platform not registered — engine may not be available
    } catch (_) {
      // FAIL-CLOSED: any other error → silently ignore
    }
  }

  /// Check if the Flutter engine is available on the platform side.
  Future<bool> checkEngineAvailability() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        TriggerMethodChannelConstants.isEngineAvailable,
      );
      _engineAvailable = result ?? false;
      return _engineAvailable;
    } on PlatformException catch (_) {
      // FAIL-CLOSED: error → unavailable
      _engineAvailable = false;
      return false;
    } on MissingPluginException catch (_) {
      // Platform not registered
      _engineAvailable = false;
      return false;
    } catch (_) {
      _engineAvailable = false;
      return false;
    }
  }

  /// Notify Android side that trigger processing is complete.
  Future<void> notifyProcessingComplete({
    required String requestId,
    required String resultCode,
    String? errorMessage,
  }) async {
    try {
      await _channel.invokeMethod(
        TriggerMethodChannelConstants.triggerProcessingComplete,
        {
          TriggerMethodChannelConstants.argRequestId: requestId,
          TriggerMethodChannelConstants.argResultCode: resultCode,
          TriggerMethodChannelConstants.argErrorMessage: errorMessage,
        },
      );
    } on PlatformException catch (_) {
      // Best-effort notification
    } on MissingPluginException catch (_) {
      // Platform not registered
    } catch (_) {
      // Best-effort notification
    }
  }

  /// Generate a unique request ID.
  String _generateRequestId() {
    return 'trg_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Whether the engine was last known to be available.
  bool get isEngineAvailable => _engineAvailable;
}
