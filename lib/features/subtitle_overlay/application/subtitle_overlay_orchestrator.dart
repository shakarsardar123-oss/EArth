/// subtitle_overlay_orchestrator.dart
/// AURA Assistant – Step 27: Live Kurdish Subtitle Overlay
///
/// Orchestrates SubtitleOverlayService + OverlayRendererRepository.
/// FAIL-CLOSED: any error → deny, unknown → deny.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/subtitle_entry.dart';
import '../domain/models/subtitle_overlay_state.dart';
import '../domain/repositories/overlay_renderer_repository.dart';
import '../domain/services/subtitle_overlay_service.dart';
import 'providers.dart';

class SubtitleOverlayOrchestrator {
  final SubtitleOverlayService _overlayService;
  final OverlayRendererRepository _rendererRepository;

  SubtitleOverlayOrchestrator({
    required SubtitleOverlayService overlayService,
    required OverlayRendererRepository rendererRepository,
  })  : _overlayService = overlayService,
        _rendererRepository = rendererRepository;

  /// Show overlay window.
  /// FAIL-CLOSED: permission denied or unavailable → deny.
  Future<OverlayVerdict> showOverlay() async {
    if (!_rendererRepository.isAvailable) return OverlayVerdict.denied;
    if (!_rendererRepository.hasPermission) {
      final permResult = await _rendererRepository.requestPermission();
      if (permResult.isDenied) return OverlayVerdict.denied;
    }
    if (!_overlayService.isAvailable) return OverlayVerdict.denied;
    if (!_overlayService.hasPermission) return OverlayVerdict.denied;
    return _overlayService.showOverlay();
  }

  /// Hide overlay window.
  Future<SubtitleOverlayState> hideOverlay() async {
    return _overlayService.hideOverlay();
  }

  /// Push a subtitle entry to the overlay.
  /// FAIL-CLOSED: renderer failure → still push via service.
  Future<OverlayVerdict> pushSubtitle(SubtitleEntry entry) async {
    final serviceResult = await _overlayService.pushSubtitle(entry);
    if (serviceResult.isDenied) return serviceResult;
    final renderResult = await _rendererRepository.renderSubtitle(entry);
    if (renderResult.isDenied) return OverlayVerdict.denied;
    return serviceResult;
  }

  /// Remove a subtitle by ID.
  Future<SubtitleOverlayState> removeSubtitle(String id) async {
    await _rendererRepository.removeSubtitle(id);
    return _overlayService.removeSubtitle(id);
  }

  /// Clear all subtitles.
  Future<SubtitleOverlayState> clearAll() async {
    await _rendererRepository.clearAllSubtitles();
    return _overlayService.clearAll();
  }

  /// Get current overlay state.
  Future<SubtitleOverlayState> getCurrentState() async {
    return _overlayService.getCurrentState();
  }

  /// Update overlay config.
  Future<SubtitleOverlayState> updateConfig({
    double? fontSize,
    double? backgroundOpacity,
    bool? showLowConfidence,
    int? maxVisibleEntries,
  }) async {
    return _overlayService.updateConfig(
      fontSize: fontSize,
      backgroundOpacity: backgroundOpacity,
      showLowConfidence: showLowConfidence,
      maxVisibleEntries: maxVisibleEntries,
    );
  }

  /// Stream of overlay state changes.
  Stream<SubtitleOverlayState> stateStream() {
    return _overlayService.stateStream();
  }
}

final subtitleOverlayOrchestratorProvider =
    Provider<SubtitleOverlayOrchestrator>((ref) {
  return SubtitleOverlayOrchestrator(
    overlayService: ref.watch(subtitleOverlayServiceProvider),
    rendererRepository: ref.watch(overlayRendererRepositoryProvider),
  );
});
