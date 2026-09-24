import 'dart:async';

import '../../application/controller/trigger_controller.dart';
import '../../domain/entities/trigger_result.dart';
import 'trigger_platform_service.dart';

/// Runtime bridge for Step 24.
///
/// Connects platform-delivered pending triggers to the real
/// TriggerController. This is intentionally separate from the
/// MethodChannel transport so the platform service remains a
/// transport boundary only.
class TriggerRuntimeService {
  final TriggerPlatformService platform;
  final TriggerController controller;

  Timer? _pollTimer;
  bool _processing = false;

  TriggerRuntimeService({
    required this.platform,
    required this.controller,
  });

  /// Start consuming Android -> Flutter pending triggers.
  void start() {
    if (_pollTimer != null) return;

    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => unawaited(processPending()),
    );

    // Process anything that arrived before the timer started.
    unawaited(processPending());
  }

  /// Stop consuming pending triggers.
  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Process all currently pending platform requests.
  Future<void> processPending() async {
    if (_processing) return;

    // Recover Android ACTION_ASSIST requests first. This is what makes
    // cold-start delivery reliable.
    await platform.recoverPendingTriggers();

    if (!platform.hasPendingRequests) return;

    _processing = true;

    try {
      final requestIds = List<String>.from(
        platform.pendingRequestIds,
      );

      for (final requestId in requestIds) {
        final request = platform.popPendingRequest(requestId);

        if (request == null) {
          continue;
        }

        TriggerResult result;

        try {
          result = await controller.processTrigger(request);
        } catch (_) {
          result = TriggerResult.denied(
            requestId: request.requestId,
            triggerType: request.triggerType,
            denialReason: 'runtime_processing_error',
            localizedResponse: 'ڕێگەپێنەدراو — هەڵەی پرۆسەکردن',
          );
        }

        await platform.notifyProcessingComplete(
          requestId: request.requestId,
          resultCode: _resultCode(result),
          errorMessage: result.wasFailed || result.wasDenied
              ? result.denialReason
              : null,
        );
      }
    } finally {
      _processing = false;
    }
  }

  String _resultCode(TriggerResult result) {
    if (result.launched) return 'launched';
    if (result.wasDenied) return 'denied';
    if (result.wasFailed) return 'failed';
    if (result.wasUnavailable) return 'unavailable';
    return 'unknown';
  }

  void dispose() {
    stop();
  }
}
