/// providers.dart
/// AURA Assistant – Step 27: Screen Target — Riverpod providers
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/repositories/screen_action_repository.dart';
import '../domain/repositories/vision_repository.dart';
import '../domain/services/screen_correction_service.dart';
import '../domain/services/screen_detection_service.dart';

final screenDetectionServiceProvider = Provider<ScreenDetectionService>((ref) {
  throw UnimplementedError('screenDetectionServiceProvider must be overridden');
});

final screenCorrectionServiceProvider = Provider<ScreenCorrectionService>((ref) {
  throw UnimplementedError('screenCorrectionServiceProvider must be overridden');
});

final visionRepositoryProvider = Provider<VisionRepository>((ref) {
  throw UnimplementedError('visionRepositoryProvider must be overridden');
});

final screenActionRepositoryProvider = Provider<ScreenActionRepository>((ref) {
  throw UnimplementedError('screenActionRepositoryProvider must be overridden');
});
