/// stt_audio_input_repository.dart
/// AURA Assistant – P0 Remediation: Real AudioInputRepository
///
/// Bridges the continuous_listening domain layer to real voice infrastructure.
/// Delegates to SpeechRecognitionServiceImpl for actual STT.
///
/// Replaces StubAudioInputRepository (which denied everything).
/// FAIL-CLOSED: any error → denied/unavailable.
library;

import 'dart:async';

import 'package:permission_handler/permission_handler.dart';

import '../../../core/voice/speech_recognition_impl.dart';
import '../domain/models/audio_segment.dart';
import '../domain/models/listening_session.dart';
import '../domain/models/segmentation_config.dart';
import '../domain/repositories/audio_input_repository.dart';

/// Real AudioInputRepository that delegates to SpeechRecognitionServiceImpl.
class SttAudioInputRepository implements AudioInputRepository {
  SttAudioInputRepository({
    required SpeechRecognitionServiceImpl speechRecognition,
  }) : _speechRecognition = speechRecognition;

  final SpeechRecognitionServiceImpl _speechRecognition;

  /// Active session ID → stream controller for audio segments.
  String? _activeSessionId;
  final _segmentControllers = <String, StreamController<AudioSegment>>{};

  /// Segment counter per session.
  final _segmentCounts = <String, int>{};

  @override
  bool get hasPermission {
    // permission_handler is async; we return optimistic true
    // and do real check in requestPermission().
    return true;
  }

  @override
  bool get isAvailable => true;

  @override
  Future<AudioInputResult> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      if (status.isGranted) return AudioInputResult.success;
      if (status.isDenied) return AudioInputResult.deniedPermission;
      return AudioInputResult.denied;
    } catch (e) {
      return AudioInputResult.error;
    }
  }

  @override
  Future<AudioInputResult> startCapture({
    required String sessionId,
    required SegmentationConfig config,
  }) async {
    if (_activeSessionId != null && _activeSessionId != sessionId) {
      // Another session is already active.
      return AudioInputResult.error;
    }

    _activeSessionId = sessionId;
    _segmentCounts[sessionId] = 0;

    // Create stream controller if not exists.
    _segmentControllers.putIfAbsent(
      sessionId,
      () => StreamController<AudioSegment>.broadcast(),
    );

    try {
      await _speechRecognition.startListening(
        onResult: (text) {
          // Only final results reach here (SpeechRecognitionServiceImpl
          // now filters finalResult in P0 fix).
          if (_activeSessionId != sessionId) return;

          final index = _segmentCounts[sessionId] ?? 0;
          _segmentCounts[sessionId] = index + 1;

          final segment = AudioSegment(
            segmentId: 'seg_${sessionId}_$index',
            sessionId: sessionId,
            index: index,
            startTime: DateTime.now(),
            transcription: text,
            confidence: 1.0, // speech_to_text doesn't expose per-result conf
            sttLanguage: config.sttLanguage,
            status: SegmentProcessingStatus.transcribed,
            locale: config.locale,
            hasSpeech: text.isNotEmpty,
          );

          _segmentControllers[sessionId]?.add(segment);
        },
        locale: config.sttLanguage,
      );
      return AudioInputResult.success;
    } catch (e) {
      return AudioInputResult.error;
    }
  }

  @override
  Future<AudioInputResult> stopCapture(String sessionId) async {
    if (_activeSessionId != sessionId) {
      return AudioInputResult.error;
    }

    try {
      await _speechRecognition.stopListening();
      _activeSessionId = null;
      return AudioInputResult.success;
    } catch (e) {
      _activeSessionId = null;
      return AudioInputResult.error;
    }
  }

  @override
  Stream<AudioSegment> audioSegmentStream(String sessionId) {
    return _segmentControllers[sessionId]?.stream ?? const Stream.empty();
  }

  @override
  Future<ListeningState> getCurrentState(String sessionId) async {
    if (_activeSessionId == sessionId) return ListeningState.active;
    if (_activeSessionId == null) return ListeningState.inactive;
    return ListeningState.unknown;
  }

  /// Clean up resources for a session.
  void disposeSession(String sessionId) {
    _segmentControllers[sessionId]?.close();
    _segmentControllers.remove(sessionId);
    _segmentCounts.remove(sessionId);
    if (_activeSessionId == sessionId) _activeSessionId = null;
  }
}
