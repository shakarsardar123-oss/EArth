/// providers.dart
/// AURA Assistant – Step 27: Subtitle Overlay — Riverpod providers
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/repositories/overlay_renderer_repository.dart';
import '../domain/services/subtitle_overlay_service.dart';

final subtitleOverlayServiceProvider = Provider<SubtitleOverlayService>((ref) {
  throw UnimplementedError('subtitleOverlayServiceProvider must be overridden');
});

final overlayRendererRepositoryProvider = Provider<OverlayRendererRepository>((ref) {
  throw UnimplementedError('overlayRendererRepositoryProvider must be overridden');
});

final overlayVisibleProvider = StateProvider<bool>((ref) => false);

final subtitleFontSizeProvider = StateProvider<double>((ref) => 18.0);

final subtitleBackgroundOpacityProvider = StateProvider<double>((ref) => 0.7);
