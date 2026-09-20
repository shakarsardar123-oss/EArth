/// stub_repository_fail_closed_test.dart
/// Step 27 structural validation — all stubs are FAIL-CLOSED.
library;

import 'package:flutter_test/flutter_test.dart';

// FAIL-CLOSED stub repositories under verification. Without these imports the
// test references undefined identifiers and cannot compile. Each stub must keep
// returning unavailable/denied — this guards against a stub being silently
// turned into fake success (Phase 4 rule 7).
import 'package:aura_assistant/features/device_connectivity/infrastructure/stub_device_transport_repository.dart';
import 'package:aura_assistant/features/real_time_translation/infrastructure/stub_translation_engine_repository.dart';
import 'package:aura_assistant/features/continuous_listening/infrastructure/stub_audio_input_repository.dart';
import 'package:aura_assistant/features/subtitle_overlay/infrastructure/stub_overlay_renderer_repository.dart';
import 'package:aura_assistant/features/screen_target/infrastructure/stub_vision_repository.dart';
import 'package:aura_assistant/features/screen_target/infrastructure/stub_screen_action_repository.dart';
import 'package:aura_assistant/features/resource_optimization/infrastructure/stub_system_resource_repository.dart';
import 'package:aura_assistant/features/api_reliability/infrastructure/stub_api_gateway_repository.dart';

void main() {
  group('Stub Repository FAIL-CLOSED', () {
    test('StubDeviceTransportRepository.isTransportAvailable returns false', () async {
      final repo = StubDeviceTransportRepository();
      expect(await repo.isTransportAvailable(), isFalse);
    });

    test('StubTranslationEngineRepository.isEngineAvailable returns false', () async {
      final repo = StubTranslationEngineRepository();
      expect(await repo.isEngineAvailable(), isFalse);
    });

    test('StubAudioInputRepository.isAvailable returns false', () {
      final repo = StubAudioInputRepository();
      expect(repo.isAvailable, isFalse);
    });

    test('StubOverlayRendererRepository.isAvailable returns false', () {
      final repo = StubOverlayRendererRepository();
      expect(repo.isAvailable, isFalse);
    });

    test('StubVisionRepository.isAvailable returns false', () {
      final repo = StubVisionRepository();
      expect(repo.isAvailable, isFalse);
    });

    test('StubScreenActionRepository.isAvailable returns false', () {
      final repo = StubScreenActionRepository();
      expect(repo.isAvailable, isFalse);
    });

    test('StubSystemResourceRepository.isAvailable returns false', () {
      final repo = StubSystemResourceRepository();
      expect(repo.isAvailable, isFalse);
    });

    test('StubApiGatewayRepository.isAvailable returns false', () {
      final repo = StubApiGatewayRepository();
      expect(repo.isAvailable, isFalse);
    });
  });
}
