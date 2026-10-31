/// continuous_listening_orchestrator.dart
/// AURA Assistant – Step 27: Continuous Listening & Smart Segmentation
///
/// Orchestrates ContinuousListeningService + AudioInputRepository.
/// FAIL-CLOSED: any error → deny, unknown → deny.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/audio_segment.dart';
import '../domain/models/listening_session.dart';
import '../domain/models/segmentation_config.dart';
import '../domain/repositories/audio_input_repository.dart';
import '../domain/services/continuous_listening_service.dart';
import 'providers.dart';

class ContinuousListeningOrchestrator {
  final ContinuousListeningService _listeningService;
  final AudioInputRepository _audioRepository;

  ContinuousListeningOrchestrator({
    required ContinuousListeningService listeningService,
    required AudioInputRepository audioRepository,
  })  : _listeningService = listeningService,
        _audioRepository = audioRepository;

  /// Start a listening session.
  /// FAIL-CLOSED: permission denied or service unavailable → deny.
  Future<ListeningVerdict> startSession(
    String sessionId,
    SegmentationConfig config,
  ) async {
    if (!_audioRepository.isAvailable) return ListeningVerdict.denied;
    if (!_audioRepository.hasPermission) {
      final permResult = await _audioRepository.requestPermission();
      if (permResult.isDenied) return ListeningVerdict.denied;
    }
    if (!_listeningService.isAvailable) return ListeningVerdict.denied;
    if (!_listeningService.hasPermission) return ListeningVerdict.denied;
    return _listeningService.startSession(sessionId, config);
  }

  /// Pause a session.
  Future<ListeningSession> pauseSession(String sessionId) async {
    return _listeningService.pauseSession(sessionId);
  }

  /// Resume a session.
  Future<ListeningVerdict> resumeSession(String sessionId) async {
    return _listeningService.resumeSession(sessionId);
  }

  /// Stop a session.
  Future<ListeningSession> stopSession(String sessionId) async {
    return _listeningService.stopSession(sessionId);
  }

  /// Get session state.
  Future<ListeningSession> getSessionState(String sessionId) async {
    return _listeningService.getSessionState(sessionId);
  }

  /// Stream of audio segments.
  Stream<AudioSegment> segmentStream(String sessionId) {
    return _listeningService.segmentStream(sessionId);
  }

  /// Update segmentation config.
  Future<ListeningSession> updateConfig(
    String sessionId,
    SegmentationConfig config,
  ) async {
    return _listeningService.updateConfig(sessionId, config);
  }
}

final continuousListeningOrchestratorProvider =
    Provider<ContinuousListeningOrchestrator>((ref) {
  return ContinuousListeningOrchestrator(
    listeningService: ref.watch(continuousListeningServiceProvider),
    audioRepository: ref.watch(audioInputRepositoryProvider),
  );
});
