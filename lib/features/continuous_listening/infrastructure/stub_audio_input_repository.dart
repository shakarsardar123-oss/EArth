/// stub_audio_input_repository.dart
/// AURA Assistant – Step 27: Continuous Listening
///
/// FAIL-CLOSED stub: all operations return denied/unavailable.
library;

import '../domain/models/audio_segment.dart';
import '../domain/models/listening_session.dart';
import '../domain/models/segmentation_config.dart';
import '../domain/repositories/audio_input_repository.dart';

class StubAudioInputRepository implements AudioInputRepository {
  @override
  bool get hasPermission => false;

  @override
  bool get isAvailable => false;

  @override
  Future<AudioInputResult> requestPermission() async => AudioInputResult.denied;

  @override
  Future<AudioInputResult> startCapture({
    required String sessionId,
    required SegmentationConfig config,
  }) async => AudioInputResult.unavailable;

  @override
  Future<AudioInputResult> stopCapture(String sessionId) async =>
      AudioInputResult.unavailable;

  @override
  Stream<AudioSegment> audioSegmentStream(String sessionId) => const Stream.empty();

  @override
  Future<ListeningState> getCurrentState(String sessionId) async =>
      ListeningState.unknown;
}
