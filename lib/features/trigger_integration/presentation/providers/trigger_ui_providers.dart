/// Step 24 — Trigger UI Providers
///
/// State management providers for the trigger integration UI.
/// These are structural placeholders — not tied to a specific
/// state management library (Riverpod, Bloc, etc).
/// FAIL-CLOSED: default state is idle/denied-oriented.

import '../../domain/entities/trigger_request.dart';
import '../../domain/entities/trigger_result.dart';
import '../../domain/value_objects/trigger_type.dart';
import '../state/trigger_ui_state.dart';
import '../../application/controller/trigger_controller.dart';

class TriggerUiNotifier {
  TriggerUiState _state = TriggerUiState.initial();
  final TriggerController _controller;

  TriggerUiNotifier({required TriggerController controller})
      : _controller = controller;

  /// Current UI state.
  TriggerUiState get state => _state;

  /// Process a trigger and update UI state accordingly.
  /// FAIL-CLOSED: any error → denied/failed state.
  Future<void> processTrigger(TriggerRequest request) async {
    _state = TriggerUiState.validating(request.triggerType);

    try {
      final result = await _controller.processTrigger(request);

      if (result.launched) {
        _state = TriggerUiState.launched(result);
      } else if (result.wasDenied) {
        _state = TriggerUiState.denied(result);
      } else if (result.wasFailed) {
        _state = TriggerUiState.failed(result);
      } else if (result.wasUnavailable) {
        _state = TriggerUiState.unavailable(result);
      } else {
        // FAIL-CLOSED: unknown result → denied state
        _state = TriggerUiState.denied(TriggerResult.denied(
          requestId: request.requestId,
          triggerType: request.triggerType,
          denialReason: 'unknown_result_state',
          localizedResponse: 'ڕێگەپێنەدراو — دۆخ نەناسراوە',
        ));
      }
    } catch (e) {
      // FAIL-CLOSED: processing error → denied state
      _state = TriggerUiState.denied(TriggerResult.denied(
        requestId: request.requestId,
        triggerType: request.triggerType,
        denialReason: 'ui_processing_error',
        localizedResponse: 'ڕێگەپێنەدراو — هەڵە',
      ));
    }
  }

  /// Reset UI state to idle.
  void reset() {
    _state = TriggerUiState.initial();
  }

  /// Convenience: process a quick settings trigger.
  Future<void> processQuickSettings({
    required String requestId,
    String? textPayload,
    bool isVoiceInput = true,
    String locale = 'ku',
  }) async {
    final request = TriggerRequest(
      requestId: requestId,
      triggerType: TriggerType.quickSettings,
      source: 'quick_settings',
      timestamp: DateTime.now(),
      textPayload: textPayload,
      isVoiceInput: isVoiceInput,
      locale: locale,
    );
    await processTrigger(request);
  }

  /// Convenience: process a notification action trigger.
  Future<void> processNotificationAction({
    required String requestId,
    required String actionLabel,
    String locale = 'ku',
  }) async {
    final request = TriggerRequest(
      requestId: requestId,
      triggerType: TriggerType.notificationAction,
      source: 'notification',
      timestamp: DateTime.now(),
      textPayload: actionLabel,
      metadata: {'actionLabel': actionLabel},
      locale: locale,
    );
    await processTrigger(request);
  }
}
