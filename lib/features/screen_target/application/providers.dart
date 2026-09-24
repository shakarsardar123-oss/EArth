/// providers.dart
/// AURA Assistant – Step 27: Screen Target — Riverpod providers
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/screen_capture/screen_capture_provider.dart';
import '../../../core/screen_understanding/screen_understanding_provider.dart';
import '../../../presentation/providers/app_providers.dart';
import '../domain/repositories/screen_action_repository.dart';
import '../domain/repositories/vision_repository.dart';
import '../domain/services/screen_correction_service.dart';
import '../domain/services/screen_detection_service.dart';
import '../infrastructure/repositories/android_screen_action_repository.dart';
import '../infrastructure/repositories/screen_understanding_vision_repository.dart';
import '../infrastructure/services/android_screen_correction_service.dart';
import '../infrastructure/services/android_screen_detection_service.dart';

final screenDetectionServiceProvider = Provider<ScreenDetectionService>((ref) {
  return const AndroidScreenDetectionService();
});

final screenCorrectionServiceProvider = Provider<ScreenCorrectionService>((ref) {
  return const AndroidScreenCorrectionService();
});

final visionRepositoryProvider = Provider<VisionRepository>((ref) {
  return ScreenUnderstandingVisionRepository(
    screenCapture: ref.watch(screenCaptureServiceProvider),
    screenUnderstanding: ref.watch(screenUnderstandingServiceProvider),
    systemControl: ref.watch(systemControlChannelProvider),
  );
});

final screenActionRepositoryProvider = Provider<ScreenActionRepository>((ref) {
  return AndroidScreenActionRepository(
    systemControl: ref.watch(systemControlChannelProvider),
  );
});
