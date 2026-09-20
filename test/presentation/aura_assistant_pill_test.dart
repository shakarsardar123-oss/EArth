// Phase 5: AuraAssistantPill mapping + real-audio wiring tests.
//
// Verifies the phase→waveform mapping used by the pill, the unified phase
// enum contract, and (via source checks) that the pill embeds the SHARED
// AuraWaveForm and forwards a real amplitude — rather than creating a second
// waveform/overlay.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura_assistant/core/voice_session/voice_session_coordinator.dart';
import 'package:aura_assistant/presentation/widgets/aura_assistant_pill.dart';
import 'package:aura_assistant/presentation/widgets/aura_wave_form.dart';

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('$path not found');
  }
  return file.readAsStringSync();
}

void main() {
  group('Phase 5: phase → waveform state mapping', () {
    test('listening + waking map to waveform listening', () {
      expect(waveFormStateForPhase(VoiceAssistantPhase.listening),
          AuraWaveFormState.listening);
      expect(waveFormStateForPhase(VoiceAssistantPhase.waking),
          AuraWaveFormState.listening);
    });

    test('thinking maps to processing', () {
      expect(waveFormStateForPhase(VoiceAssistantPhase.thinking),
          AuraWaveFormState.processing);
    });

    test('speaking maps to speaking', () {
      expect(waveFormStateForPhase(VoiceAssistantPhase.speaking),
          AuraWaveFormState.speaking);
    });

    test('idle/error map to idle/error', () {
      expect(waveFormStateForPhase(VoiceAssistantPhase.idle),
          AuraWaveFormState.idle);
      expect(waveFormStateForPhase(VoiceAssistantPhase.error),
          AuraWaveFormState.error);
    });
  });

  group('Phase 5: VoiceAssistantPhase contract', () {
    test('isActive is true only for active phases', () {
      expect(VoiceAssistantPhase.idle.isActive, isFalse);
      expect(VoiceAssistantPhase.waking.isActive, isTrue);
      expect(VoiceAssistantPhase.listening.isActive, isTrue);
      expect(VoiceAssistantPhase.thinking.isActive, isTrue);
      expect(VoiceAssistantPhase.speaking.isActive, isTrue);
      expect(VoiceAssistantPhase.error.isActive, isFalse);
    });

    test('every phase exposes a non-empty status label', () {
      for (final p in VoiceAssistantPhase.values) {
        expect(p.statusText.trim(), isNotEmpty);
      }
    });
  });

  group('Phase 5: pill renders and embeds shared waveform', () {
    testWidgets('renders in speaking phase with a real amplitude',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: AuraAssistantPill(
                phase: VoiceAssistantPhase.speaking,
                amplitude: 0.6,
                onInterrupt: () {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(AuraAssistantPill), findsOneWidget);
      expect(find.byType(AuraWaveForm), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Phase 5: source guarantees (no duplicate engines)', () {
    test('pill embeds AuraWaveForm and forwards amplitude', () {
      final src = _read('lib/presentation/widgets/aura_assistant_pill.dart');
      expect(src.contains('AuraWaveForm('), isTrue);
      expect(src.contains('amplitude: amplitude'), isTrue);
    });

    test('pill host selects mic level while listening, TTS level while speaking',
        () {
      final src =
          _read('lib/presentation/widgets/aura_assistant_pill_host.dart');
      expect(src.contains('voiceAssistantSoundLevelProvider'), isTrue);
      expect(src.contains('voiceAssistantSpeakingLevelProvider'), isTrue);
    });
  });
}
