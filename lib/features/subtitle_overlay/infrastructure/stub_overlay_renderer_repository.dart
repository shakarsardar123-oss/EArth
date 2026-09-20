/// stub_overlay_renderer_repository.dart
/// AURA Assistant – Step 27: Subtitle Overlay
///
/// FAIL-CLOSED stub: all operations return denied/unavailable.
library;

import '../domain/models/subtitle_entry.dart';
import '../domain/models/subtitle_overlay_state.dart';
import '../domain/repositories/overlay_renderer_repository.dart';

class StubOverlayRendererRepository implements OverlayRendererRepository {
  @override
  bool get hasPermission => false;

  @override
  bool get isAvailable => false;

  @override
  Future<OverlayRenderResult> requestPermission() async =>
      OverlayRenderResult.denied;

  @override
  Future<OverlayRenderResult> showOverlayWindow() async =>
      OverlayRenderResult.unavailable;

  @override
  Future<OverlayRenderResult> hideOverlayWindow() async =>
      OverlayRenderResult.unavailable;

  @override
  Future<OverlayRenderResult> renderSubtitle(SubtitleEntry entry) async =>
      OverlayRenderResult.denied;

  @override
  Future<OverlayRenderResult> removeSubtitle(String subtitleId) async =>
      OverlayRenderResult.unavailable;

  @override
  Future<OverlayRenderResult> clearAllSubtitles() async =>
      OverlayRenderResult.unavailable;

  @override
  Future<OverlayVisibility> getVisibility() async => OverlayVisibility.unknown;

  @override
  Stream<SubtitleOverlayState> overlayStateStream() => const Stream.empty();
}
