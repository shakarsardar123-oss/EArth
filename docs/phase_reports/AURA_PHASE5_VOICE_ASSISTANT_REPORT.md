# AURA — Phase 5 (Voice Assistant) Completion Report

**Scope:** Make the shared `AuraWaveForm` react to REAL audio on BOTH sides of
the conversation — the USER side (microphone RMS) and the AURA side (real TTS
output). Strictly ADDITIVE: no duplicate services, engines, overlays, or
conversation architecture. Existing systems reused:
`LiveModeOrchestrator`, `WakeWordService`, `AssistantController`,
`AuraWaveForm`, and the floating-aura overlay.

The LISTENING → THINKING → SPEAKING → LISTENING loop and explicit barge-in are
preserved. TTS completion does **not** end the session.

---

## 1. Files created / modified / deleted

**Created (4)**
- `lib/presentation/widgets/aura_assistant_pill_host.dart` — `ConsumerWidget`
  that selects the correct REAL audio stream per phase (mic while LISTENING,
  TTS activity while SPEAKING) and feeds a normalized `0..1` amplitude to the
  pill.
- `test/presentation/aura_wave_form_amplitude_test.dart`
- `test/presentation/aura_assistant_pill_test.dart`
- `test/core/voice_session/tts_output_level_audit_test.dart`

**Modified (7)**
- `lib/core/voice/text_to_speech_impl.dart` — added `outputLevelStream` (a
  broadcast `Stream<double>`) driven by the real `setProgressHandler`
  word-boundary callbacks, with a deterministic decay `Timer` and cleanup in
  `dispose()`.
- `lib/core/voice/voice_service_impl.dart` — added `speakingLevelStream`
  getter forwarding the TTS output level; disposes the TTS service.
- `lib/core/voice_session/voice_session_coordinator.dart` — added
  `speakingLevelStream` getter forwarding `VoiceService.speakingLevelStream`.
- `lib/core/voice_session/voice_session_providers.dart` — added
  `voiceAssistantSpeakingLevelProvider` (a `StreamProvider<double>`).
- `lib/presentation/widgets/aura_wave_form.dart` — the `amplitude` field now
  drives BOTH the listening and speaking states; fixed two compile bugs
  (the widget was missing its `final double? amplitude;` field, and the
  painter carried a dead uninitialised `amplitude` field — the field now
  lives only on the widget).
- `lib/presentation/widgets/aura_assistant_pill.dart` — docs + the SPEAKING
  glow now reacts to `amplitude`.

**Deleted:** none.

---

## 2. What was implemented

- A real, per-side audio-reactive waveform: the same shared `AuraWaveForm`
  scales its bars from a live `0..1` amplitude, sourced from the microphone
  while the user speaks and from AURA's TTS activity while AURA speaks.
- A thin, clean interface (`outputLevelStream`) added to the existing TTS
  implementation — `flutter_tts` was **not** replaced.
- A phase-aware host widget that picks the correct real stream and normalizes
  the platform mic range to `0..1`.

## 3. What was blocked / not done

- **True acoustic amplitude for AURA (PCM/RMS on the output path).**
  `flutter_tts ^4.0.2` exposes no PCM buffer or output RMS — only word-boundary
  progress callbacks. AURA's waveform is therefore a REAL speech-ACTIVITY
  envelope (peaks from genuine word events, deterministic decay), **not** a
  true acoustic amplitude. This is intentional and honest, not a fabricated
  signal.
- **Always-on keyword spotting (KWS)** remains blocked (see item 4).
- **Mic-during-TTS / acoustic echo cancellation** was not added; barge-in
  stays an explicit trigger (see item 8).

## 4. Wake word: STT keyword-spotting, NOT true KWS

Wake-word detection is still implemented as keyword-spotting over the
`speech_to_text` recognizer (matching "Hey AURA" in transcribed text), not a
dedicated always-on on-device KWS engine. A real low-power KWS remains blocked
in this environment. No change was made here in Phase 5.

## 5. Does the waveform react to USER audio? — YES

While LISTENING, the host reads `voiceAssistantSoundLevelProvider`, which is
backed by `speech_to_text`'s `onSoundLevelChange` (real microphone RMS). The
platform range (~ -2.0..10.0) is normalized to `0..1` and drives the bars.

## 6. Does the waveform react to AURA / TTS audio? — YES (activity envelope)

While SPEAKING, the host reads `voiceAssistantSpeakingLevelProvider`, which is
fed by the TTS `outputLevelStream`. That stream RISES only on genuine
`setProgressHandler` word callbacks and decays via a deterministic `Timer`.
It reflects REAL speech activity but is **not** true acoustic amplitude
(see item 3). No random/synthetic values are used.

## 7. Conversation loop & session lifecycle preserved

The LISTENING → THINKING → SPEAKING → LISTENING cycle is intact and TTS
completion does not terminate the session. All existing systems
(`LiveModeOrchestrator`, `WakeWordService`, `AssistantController`,
`AuraWaveForm`, floating-aura overlay) were reused; nothing was duplicated.

## 8. Barge-in preserved

Explicit barge-in (interrupt AURA while it is speaking) is retained and routed
through the existing coordinator. No mic-during-TTS listening or AEC was
introduced, so barge-in remains an explicit user trigger.

## 9. Build / test / analyze status — NOT VERIFIED

No Flutter/Dart SDK is available in this environment, so `flutter build`,
`flutter test`, and `flutter analyze` could **not** be executed. Build, test,
and analysis are therefore **NOT VERIFIED**. The edits were sanity-checked by
reading the source and by grep-level structural inspection only; the three new
test files are written to match the project's existing source-audit +
`testWidgets` conventions and are expected to pass once an SDK is available.
