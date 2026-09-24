/// Riverpod providers for the AURA screen-understanding subsystem.
///
/// Exposes:
/// - [screenUnderstandingServiceProvider] — the concrete
///   [ScreenUnderstandingService] instance.
/// - [screenUnderstandingStateProvider] — the current
///   [ScreenUnderstandingState] as a [StateNotifierProvider].
///
/// Pattern follows existing AURA provider conventions:
/// Provider for services, StateNotifierProvider for mutable state.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/result.dart';
import '../errors/failures.dart';
import '../screen_capture/screen_capture_result.dart';
import 'screen_understanding_result.dart';
import 'screen_understanding_state.dart';
import 'screen_understanding_service.dart';
import 'screen_understanding_engine.dart';
import '../../services/vision/vision_service_factory.dart'
    show visionServiceProvider;

/// Provider for the [ScreenUnderstandingService] singleton.
///
/// Default: [ScreenUnderstandingEngine] backed by the
/// [visionServiceProvider]. Override this provider in tests
/// to inject a fake.
final screenUnderstandingServiceProvider =
    Provider<ScreenUnderstandingService>((ref) {
  final visionService = ref.watch(visionServiceProvider);
  return ScreenUnderstandingEngine(
    visionService: visionService,
  );
});

/// StateNotifier that wraps a [ScreenUnderstandingService] and
/// publishes [ScreenUnderstandingState] changes to Riverpod.
class ScreenUnderstandingStateNotifier
    extends StateNotifier<ScreenUnderstandingState> {
  ScreenUnderstandingStateNotifier(this._service)
      : super(const ScreenUnderstandingState());

  final ScreenUnderstandingService _service;
  StreamSubscription<ScreenUnderstandingState>? _stateSub;

  /// Current service reference (read-only for tests).
  ScreenUnderstandingService get service => _service;

  /// Analyze a single captured frame.
  ///
  /// Delegates to the underlying [ScreenUnderstandingService]
  /// and updates state accordingly.
  Future<Result<ScreenRepresentation, ScreenUnderstandingFailure>>
      analyzeFrame(CapturedFrame frame) async {
    final result = await _service.analyzeFrame(frame);

    // Sync state from service after analysis completes.
    state = _service.state;

    return result;
  }

  /// Start continuous analysis of a frame stream.
  ///
  /// Subscribes to the service's state stream to keep this
  /// notifier's state in sync.
  void startStreamAnalysis(Stream<CapturedFrame> frameStream) {
    _stateSub?.cancel();
    _stateSub = _service.stateStream.listen(
      (newState) {
        state = newState;
      },
      onError: (Object error) {
        // State errors are already reflected in the service's
        // state; just sync it.
        state = _service.state;
      },
    );

    _service.analyzeLatestFrame(frameStream);
  }

  /// Cancel any in-progress analysis.
  void cancel() {
    _service.cancel();
    state = _service.state;
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _service.dispose();
    super.dispose();
  }
}

/// StateNotifierProvider for screen-understanding state.
///
/// Tests can override this with a controlled notifier.
final screenUnderstandingStateProvider =
    StateNotifierProvider<ScreenUnderstandingStateNotifier,
        ScreenUnderstandingState>((ref) {
  final service = ref.watch(screenUnderstandingServiceProvider);
  return ScreenUnderstandingStateNotifier(service);
});
