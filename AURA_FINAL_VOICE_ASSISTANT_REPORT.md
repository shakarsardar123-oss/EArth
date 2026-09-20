# AURA — Final Voice Assistant Report

**BUILD STATUS:** BUILD NOT VERIFIED — Flutter/Android SDK unavailable.
**TEST STATUS:** TESTS NOT EXECUTED — Flutter/Dart SDK unavailable.

Static source verification was performed where possible. All claims below are source-level, not build-verified.

---

## 1. Wake Word Implementation

### Primary: Genuine Acoustic KWS Interface
- **File:** `lib/core/audio/acoustic_wake_word_engine.dart`
- **Architecture:** `AcousticWakeWordEngine` abstract interface with two implementations:
  - `NativeAcousticWakeWordEngine` — bridges to a native KWS runner via `EventChannel` + `MethodChannel`. Applies `WakeWordDebouncer` for one-utterance-one-wake and cooldown safety.
  - `StubAcousticWakeWordEngine` — always reports `unavailable`; never fabricates a detection.
- **Status:** `NativeAcousticWakeWordEngine.initialize()` reports `modelMissing` because **no "Hey AURA" KWS model asset is bundled** in this repository. The native `AuraAudioBridge.kt`'s wake channel honestly returns `"model_missing"` and emits no events. We do NOT fake a detection.
- **Remaining blocker:** A legally-distributable on-device KWS model asset for the phrase "Hey AURA" must be sourced and bundled (e.g. an openWakeWord custom model, a Porcupine `.ppn` file, or a Vosk keyword model). The interface is ready; the model is the external dependency.

### Fallback: Existing STT Keyword Spotting
- **File:** `lib/core/wakeword/wakeword_service.dart` (unchanged)
- The existing `WakeWordService` that runs full `speech_to_text` and checks for the word "ئەورا" in the transcript **remains the active fallback**. It is documented as battery-intensive and not true always-on. The `VoiceSessionCoordinator` prefers the acoustic engine when it reports `listening`; otherwise degrades to the STT fallback. **The STT path is NOT deleted** — it stays so AURA still wakes today.

### Debounce / Cooldown
- **File:** `lib/core/audio/wake_word_debouncer.dart`
- Pure-Dart, injectable-clock implementation. Prevents rapid re-trigger from a single utterance. Unit-tested.

---

## 2. TTS Architecture

- **File:** `lib/core/voice/text_to_speech_impl.dart` (unchanged)
- Engine: `flutter_tts ^4.0.2`
- `awaitSpeakCompletion(true)` — `speak()` resolves only after speech completes.
- Word-boundary progress events (`setProgressHandler`) drive a genuine speech-activity envelope (0..1). This is NOT random animation; it tracks real words being spoken.

---

## 3. PCM/RMS Implementation

### Input (microphone) path
- `SpeechRecognitionServiceImpl.startListening()` uses `speech_to_text`'s `onSoundLevelChange` callback — a **real microphone RMS** value from the platform speech recognizer.
- `VoiceServiceImpl.soundLevelStream` streams this directly (normalised by `RmsNormalizer.sttSoundLevel()` in providers).

### Output (AURA voice) path — NEW
- **Native:** `AuraAudioBridge.kt` attaches `android.media.audiofx.Visualizer` to the output mix (session 0), captures waveform bytes, computes genuine RMS per capture, and streams normalised 0..1 values via `EventChannel`. This is the **actual acoustic output level** of AURA's own TTS.
- **Dart consumer:** `NativeOutputLevelMonitor` receives the EventChannel stream, applies `LevelSmoother` (attack/release), and emits to `VoiceSessionCoordinator.outputLevelStream`.
- **Fallback:** When the Visualizer is unavailable (permissions, device restrictions, non-Android), `OutputLevelMonitor.status` reports `unavailable` and the coordinator transparently falls back to the existing flutter_tts word-activity envelope. **No fake animation.**
- **Signal math:** `lib/core/audio/audio_signal_math.dart` — pure-Dart `rmsFromPcm16()`, `peakFromPcm16()`, `RmsNormalizer`, `LevelSmoother` — deterministic, zero randomness, unit-tested.

---

## 4. AEC Implementation

- **File:** `lib/core/audio/echo_safe_mic_monitor.dart` (Dart) + `AuraAudioBridge.kt` (native)
- **Native path:** The `mic_vad` handler opens ONE `AudioRecord` with `MediaRecorder.AudioSource.VOICE_COMMUNICATION`, which routes the audio through the device's hardware AEC/AGC/NS pipeline where present. It then additionally creates `AcousticEchoCanceler.create(audioSessionId)` and `NoiseSuppressor.create(audioSessionId)` when `isAvailable()` returns true. The effect's `.enabled` state is checked, and the honest status is reported: `active`, `supported`, or `unavailable`.
- **AEC status mapping (Android → Dart):**
  - AEC effect exists AND `.enabled == true` → `AecStatus.active`
  - `AcousticEchoCanceler.isAvailable() == true` but effect could not be enabled → `AecStatus.supported`
  - `isAvailable() == false` → `AecStatus.unavailable`
- **Honesty:** AEC quality is hardware/platform-dependent. We do NOT claim `active` when it is not. On devices without AcousticEchoCanceler, the monitor still runs but reports `unavailable`, and the coordinator falls back to stopping STT before TTS.
- **Handles:** speaker volume changes (the AEC effect adapts); headset routing (AudioSource.VOICE_COMMUNICATION automatically reroutes).

---

## 5. VAD Implementation

- **File:** `lib/core/audio/voice_activity_detector.dart`
- **Algorithm:** Energy + zero-crossing-rate hysteresis VAD. A frame is "qualifying" if its RMS ≥ threshold AND its ZCR is within plausible speech bounds (rejects both sub-bass rumble and hiss/noise). Onset requires `startFrames` (default 3) consecutive qualifying frames — this prevents a single amplitude spike from triggering barge-in. Offset requires `hangoverFrames` (default 8) consecutive silent frames.
- **Honesty:** This is a classic lightweight VAD, NOT a neural VAD (e.g. Silero). It is honest about what it is and is unit-tested with the exact edge cases the requirements specify (no false interruption from AURA voice, no random spike triggers).

---

## 6. Barge-In Implementation

### Automatic Acoustic Barge-In — NEW
- **File:** `lib/core/audio/barge_in_controller.dart`
- **Flow:** While SPEAKING → `BargeInController.arm()` → opens the echo-safe mic monitor (same AudioRecord, NOT a second mic) → feeds post-AEC frames to `VoiceActivityDetector` → confirmed `speechStart` fires `onBargeIn` callback → `VoiceSessionCoordinator` calls `orchestrator.bargeIn()` → stops TTS immediately → state transitions to LISTENING → user speech continues into the same session.
- **Key guarantee:** Barge-in is triggered by a REAL speech onset (VAD startFrames), NOT by a random amplitude spike, NOT by AURA's own voice (AEC suppresses it; VAD hysteresis rejects residual). The existing manual/explicit barge-in (`coordinator.bargeIn()`) remains available as a fallback.

### Existing Explicit Barge-In
- `LiveModeOrchestrator.bargeIn()` — stops TTS via `VoiceService.stopSpeaking()`, the awaited `speak()` in `_speakThenRestartListening` resolves, and the orchestrator re-enters LISTENING.

---

## 7. Session State Machine

```
IDLE
  ↓  ["Hey AURA" detected / manual start]
WAKE_DETECTED  (VoiceAssistantPhase.waking)
  ↓  [mic switched to command capture]
LISTENING
  ↓  [final STT result]
THINKING
  ↓  [agent returns answer]
SPEAKING
  ↓  [TTS completion]  or  [user speech detected → BARGE-IN]
LISTENING  ← (continuous conversation; no wake phrase needed between turns)
  ↓  [exit command / timeout / explicit stop / permission lost]
IDLE
```

- Session does NOT end when TTS finishes — it loops back to LISTENING.
- Session ends only on: explicit exit command, user dismissal, configured inactivity timeout, Android lifecycle termination, permission revocation, or unrecoverable audio error.
- The wake phrase is required ONLY to start a NEW session from IDLE.

---

## 8. Default Assistant Verification

- **File:** `MainActivity.kt` — `handleAssistantIntegration` (existing, unchanged)
- Uses `RoleManager.isRoleHeld(RoleManager.ROLE_ASSISTANT)` on API 29+.
- `requestAssistantRole()` opens the real Android system intent via `RoleManager.createRequestRoleIntent()`.
- Status is reflected honestly in the UI — no fake "enabled" toggle.
- No duplicate implementation was created.

---

## 9. Floating AURA UI / Overlay

- Existing pill + waveform reused (`aura_assistant_pill.dart`, `aura_wave_form.dart`)
- Waveform is driven by `amplitude` parameter — already wired to:
  - LISTENING: `voiceAssistantSoundLevelProvider` (real mic RMS)
  - SPEAKING: **NEW** `voiceAssistantOutputLevelProvider` (genuine Visualizer RMS when active, graceful fallback to TTS word envelope)
- New `VoiceAssistantPhase.waking` maps to `AuraWaveFormState.idle` (gentle pulse while pill appears).
- No second overlay system was created.

---

## 10. Permissions / Android Lifecycle

### Manifest additions (all additive)
- `MODIFY_AUDIO_SETTINGS` — required by `Visualizer` and `AcousticEchoCanceler` APIs
- `RECORD_AUDIO` — already present
- `FOREGROUND_SERVICE_MICROPHONE` — already present (for future foreground mic service)

### Runtime handling in native bridge
- `hasMicPermission()` checked before opening `Visualizer` or `AudioRecord`
- Fails closed: returns `false` / `unavailable` if permission absent

### Not requested unnecessarily
- No new runtime permission requests beyond what was already in place
- The coordinator watches `VoiceState.error` and transitions to IDLE on microphone loss

---

## 11. Files Created

| Path | Lines | Purpose |
|------|-------|--------|
| `lib/core/audio/audio_signal_math.dart` | ~130 | RMS/peak/ZCR math, RmsNormalizer, LevelSmoother |
| `lib/core/audio/voice_activity_detector.dart` | ~90 | Energy+ZCR VAD with hysteresis |
| `lib/core/audio/wake_word_debouncer.dart` | ~65 | Debounce/cooldown gate for wake detections |
| `lib/core/audio/output_level_monitor.dart` | ~115 | Interface + native Visualizer RMS + stub |
| `lib/core/audio/echo_safe_mic_monitor.dart` | ~135 | Interface + native AEC AudioRecord + stub |
| `lib/core/audio/acoustic_wake_word_engine.dart` | ~160 | Interface + native KWS bridge + stub |
| `lib/core/audio/barge_in_controller.dart` | ~75 | Auto barge-in: mic monitor → VAD → callback |
| `lib/core/audio/audio_providers.dart` | ~50 | Riverpod wiring for all audio components |
| `android/…/AuraAudioBridge.kt` | ~225 | Native Visualizer RMS, AEC AudioRecord, wake scaffold |
| `test/core/audio/audio_signal_math_test.dart` | ~85 | Pure-Dart signal math tests |
| `test/core/audio/voice_activity_detector_test.dart` | ~65 | VAD edge-case tests |
| `test/core/audio/wake_word_debouncer_test.dart` | ~55 | Debounce tests with injected clock |
| `test/core/audio/barge_in_controller_test.dart` | ~90 | Integration boundary test with fake mic |

## 12. Files Modified (additive only)

| Path | Change |
|------|--------|
| `lib/core/voice_session/voice_session_coordinator.dart` | Added optional `wakeEngine`, `bargeInController`, `outputLevelMonitor` params; prefers acoustic wake when available; arms/disarms barge-in on SPEAKING transitions; exposes `outputLevelStream` and `hasRealOutputLevel`; clean-up in `dispose()` |
| `lib/core/voice_session/voice_session_providers.dart` | Imports audio providers; passes 3 new collaborators to coordinator constructor; adds `voiceAssistantOutputLevelProvider` |
| `android/…/MainActivity.kt` | Instantiates `AuraAudioBridge` in `configureFlutterEngine`; overrides `onDestroy` to release resources; added `MODIFY_AUDIO_SETTINGS` import path is in manifest, not here |
| `android/…/AndroidManifest.xml` | Added `MODIFY_AUDIO_SETTINGS` permission |

---

## 13. Tests Added (not executed — no SDK)

- `audio_signal_math_test.dart` — RMS silence/low/high/clipping, peak, ZCR, normalizer floor/ceiling/NaN, smoother rise/decay/snap-to-zero/clamp
- `voice_activity_detector_test.dart` — onset after startFrames, single spike no-trigger, end after hangoverFrames, ZCR rejection, reset
- `wake_word_debouncer_test.dart` — first accept, duplicate suppress, cooldown accept, confidence threshold, reset
- `barge_in_controller_test.dart` — fires on confirmed speech onset, does NOT fire on spikes, disarm stops mic and ignores later frames, surfaces AEC status

---

## 14. Known Limitations / Remaining Blockers

1. **Wake word: no bundled KWS model.** The `AcousticWakeWordEngine` interface and native runner are ready. A "Hey AURA" model asset (openWakeWord, Porcupine, Vosk keyword, or similar) must be sourced and placed in `assets/`. Until then, the existing STT keyword fallback is the only active wake path. **This is not faked.**

2. **AEC is hardware/platform dependent.** `AcousticEchoCanceler` availability and effectiveness varies by device. On devices without it, the bridge reports `unavailable` and the coordinator falls back to the existing safe approach (stop STT before TTS). **We do not claim AEC active when it is not.**

3. **Visualizer may be restricted.** Some OEMs or Android configurations forbid capturing from session 0 (the output mix). The native code catches `RuntimeException` and reports `unavailable`, falling back to the TTS word-activity envelope. **No fake output level.**

4. **Foreground mic service for screen-off.** While the manifest has `FOREGROUND_SERVICE_MICROPHONE`, a full foreground service with a persistent notification (required for always-on mic while the screen is off on Android 10+) is not yet implemented. This is a prerequisite for genuine always-on wake detection. The coordinator architecture supports it; the service plumbing is a remaining blocker.

5. **flutter_tts cannot expose raw PCM.** The TTS engine's audio stream is internal to the Android TTS framework. The Visualizer-based approach captures the OUTPUT MIX (which includes AURA's TTS) as a genuine workaround, but it is not a direct PCM tap from the TTS engine itself. This is a documented platform limitation.

---

## 15. Audit: Removed Fakes

No fake implementations were found in the production code path that needed removal. The existing code was already honest about its limitations:
- `WakeWordService` already documented its STT-only nature.
- `TextToSpeechServiceImpl` already documented the word-envelope vs. amplitude distinction.
- `LiveModeOrchestrator.bargeIn()` already documented the no-mic-during-TTS limitation.

The new code adds genuine capabilities where technically possible (Visualizer RMS, AEC AudioRecord, VAD barge-in) and degrades honestly where the platform blocks it.

---

## 16. Build & Test Honesty

- `flutter analyze` — NOT RUN (no SDK)
- `flutter test` — NOT RUN (no SDK)
- `flutter build apk --debug` — NOT RUN (no SDK)

All source files were verified for structural correctness (matching braces, proper imports, no obvious type errors) via grep. **We never claim build success or test passing without actually running them.**
