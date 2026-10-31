/// providers.dart
/// AURA Assistant – P0 Remediation: Continuous Listening — Riverpod providers
///
/// CHANGED: Real implementations now override the UnimplementedError throws.
/// SttAudioInputRepository delegates to SpeechRecognitionServiceImpl.
/// LiveContinuousListeningService wraps LiveModeOrchestrator.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/voice/voice_service_provider.dart'
    show speechRecognitionProvider;
import '../../../core/live_mode/live_mode_orchestrator.dart';
import '../../../core/live_mode/live_mode_providers.dart'
    show liveModeOrchestratorProvider;
import '../domain/models/segmentation_config.dart';
import '../domain/repositories/audio_input_repository.dart';
import '../domain/services/continuous_listening_service.dart';
import '../infrastructure/stt_audio_input_repository.dart';
import '../infrastructure/live_continuous_listening_service.dart';

/// Real ContinuousListeningService — wraps LiveModeOrchestrator.
final continuousListeningServiceProvider =
    Provider<ContinuousListeningService>((ref) {
  final orchestrator = ref.watch(liveModeOrchestratorProvider);
  return LiveContinuousListeningService(orchestrator: orchestrator);
});

/// Real AudioInputRepository — delegates to SpeechRecognitionServiceImpl.
final audioInputRepositoryProvider = Provider<AudioInputRepository>((ref) {
  final speechRecognition = ref.watch(speechRecognitionProvider);
  return SttAudioInputRepository(speechRecognition: speechRecognition);
});

final segmentationConfigProvider = StateProvider<SegmentationConfig>(
  (ref) => const SegmentationConfig(mode: SegmentationMode.hybrid),
);

final isListeningProvider = StateProvider<bool>((ref) => false);