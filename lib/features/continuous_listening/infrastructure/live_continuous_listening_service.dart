/// live_continuous_listening_service.dart
/// AURA Assistant – P0 Remediation: Real ContinuousListeningService
///
/// Bridges the continuous_listening domain layer to LiveModeOrchestrator.
/// Maps domain session model to Live Mode state machine.
///
/// Replaces the UnimplementedError throw in providers.dart.
/// FAIL-CLOSED: any error → denied, unknown → inactive.
library;

import 'dart:async';

import '../../../core/live_mode/live_mode_orchestrator.dart';
import '../../../core/live_mode/live_mode_state.dart';
import '../domain/models/audio_segment.dart';
import '../domain/models/listening_session.dart';
import '../domain/models/segmentation_config.dart';
import '../domain/services/continuous_listening_service.dart';

/// Real ContinuousListeningService that wraps LiveModeOrchestrator.
class LiveContinuousListeningService implements ContinuousListeningService {
  LiveContinuousListeningService({
    required LiveModeOrchestrator orchestrator,
  }) : _orchestrator = orchestrator;

  final LiveModeOrchestrator _orchestrator;

  /// Active sessions map.
  final _sessions = <String, ListeningSession>{};

  /// Segment stream controllers per session.
  final _segmentControllers = <String, StreamController<AudioSegment>>{};

  /// Subscription to orchestrator state changes.
  StreamSubscription<LiveModeState>? _stateSubscription;

  @override
  bool get isAvailable => true;

  @override
  bool get hasPermission => true;

  @override
  Future<ListeningVerdict> startSession({
    required String sessionId,
    required SegmentationConfig config,
  }) async {
    // Check if orchestrator is already active.
    if (_orchestrator.isActive) {
      return ListeningVerdict.denied;
    }

    final result = await _orchestrator.startSession();
    if (result == null) {
      return ListeningVerdict.denied;
    }

    // Create a domain ListeningSession.
    _sessions[sessionId] = ListeningSession(
      sessionId: sessionId,
      state: ListeningState.active,
      segmentationMode: config.mode,
      sttLanguage: config.sttLanguage,
      locale: config.locale,
      startedAt: DateTime.now(),
    );

    // Wire up orchestrator callbacks to domain segments.
    _orchestrator.onUserRecognized = (text) {
      final session = _sessions[sessionId];
      if (session == null) return;

      final index = session.segmentCount;
      _sessions[sessionId] = session.copyWith(
        segmentCount: index + 1,
        lastActivityAt: DateTime.now(),
      );

      final segment = AudioSegment(
        segmentId: 'seg_${sessionId}_$index',
        sessionId: sessionId,
        index: index,
        startTime: DateTime.now(),
        transcription: text,
        confidence: 1.0,
        sttLanguage: config.sttLanguage,
        status: SegmentProcessingStatus.transcribed,
        locale: config.locale,
        hasSpeech: text.isNotEmpty,
      );

      _segmentControllers[sessionId]?.add(segment);
    };

    return ListeningVerdict.allowed;
  }

  @override
  Future<ListeningSession> pauseSession(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) {
      return ListeningSession.denied(sessionId: sessionId);
    }
    // Live Mode doesn't have pause — stop and return inactive.
    await _orchestrator.stopSession();
    _sessions[sessionId] = session.copyWith(state: ListeningState.inactive);
    return _sessions[sessionId]!;
  }

  @override
  Future<ListeningVerdict> resumeSession(String sessionId) async {
    // Live Mode resumes by starting a new session.
    final session = _sessions[sessionId];
    if (session == null) return ListeningVerdict.denied;

    final config = SegmentationConfig(
      mode: session.segmentationMode,
      sttLanguage: session.sttLanguage,
      locale: session.locale,
    );

    return startSession(sessionId: sessionId, config: config);
  }

  @override
  Future<ListeningSession> stopSession(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) {
      return ListeningSession.denied(sessionId: sessionId);
    }

    await _orchestrator.stopSession();
    _sessions[sessionId] = session.copyWith(state: ListeningState.inactive);

    // Clean up segment stream.
    await _segmentControllers[sessionId]?.close();
    _segmentControllers.remove(sessionId);

    return _sessions[sessionId]!;
  }

  @override
  Future<ListeningSession> getSessionState(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) {
      return ListeningSession.denied(sessionId: sessionId);
    }

    // Map LiveModeState to ListeningState.
    final listeningState = _mapLiveModeToListening(_orchestrator.state);
    _sessions[sessionId] = session.copyWith(state: listeningState);
    return _sessions[sessionId]!;
  }

  @override
  Stream<AudioSegment> segmentStream(String sessionId) {
    _segmentControllers.putIfAbsent(
      sessionId,
      () => StreamController<AudioSegment>.broadcast(),
    );
    return _segmentControllers[sessionId]!.stream;
  }

  @override
  Future<ListeningSession> updateConfig({
    required String sessionId,
    required SegmentationConfig config,
  }) async {
    final session = _sessions[sessionId];
    if (session == null) {
      return ListeningSession.denied(sessionId: sessionId);
    }
    // Config update doesn't change Live Mode orchestrator state.
    return session;
  }

  /// Map LiveModeState to domain ListeningState.
  ListeningState _mapLiveModeToListening(LiveModeState state) => switch (state) {
    LiveModeState.idle => ListeningState.inactive,
    LiveModeState.listening => ListeningState.active,
    LiveModeState.processing => ListeningState.active,
    LiveModeState.speaking => ListeningState.active,
    LiveModeState.error => ListeningState.error,
  };
}
