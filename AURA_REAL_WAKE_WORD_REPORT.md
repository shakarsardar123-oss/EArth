# AURA — Real Acoustic Wake Word (“Hey AURA”) — Implementation Report

**Scope:** ONE change only — make the **primary** wake word a REAL on-device
**acoustic** keyword spotter (KWS). No other AURA feature was added, removed, or
re-architected. The existing STT keyword detector is kept **only** as a
documented fallback.

**Build status:** `BUILD NOT VERIFIED` — no Flutter/Android SDK is available in
this environment (`which flutter` / `which dart` return nothing). No
`flutter pub get` / `analyze` / `test` / `build apk` was run. All statements
below are from source implementation + static inspection, not a compiled run.

---

## 1. What model is used

| Field | Value |
|---|---|
| Model | **vosk-model-small-en-us-0.15** (Vosk / Kaldi acoustic model) |
| Provider | Alpha Cephei Inc. |
| License | **Apache License 2.0** (redistributable; bundled in-repo) |
| Runtime | `com.alphacephei:vosk-android:0.3.47` (JNI, fully offline) |
| Format | Kaldi model directory (`am/`, `graph/`, `ivector/`, `conf/`) |
| Size | ~68 MB unpacked (~40 MB compressed) |
| Input | 16 kHz, mono, 16-bit PCM (`short[]`) |

### Why this model / approach
“Hey AURA” is a **custom** phrase. The realistic redistributable options were:
- **Porcupine (Picovoice)** — needs a proprietary trained `.ppn` + AccessKey; not
  freely redistributable. Rejected.
- **openWakeWord / microWakeWord** — Apache-2.0, but ship no “hey aura” model;
  a custom phrase requires an offline training pipeline (TTS data + GPU) that
  cannot run in this sandbox. Rejected for now.
- **Vosk grammar-constrained KWS** — Apache-2.0, on-device, handles an
  **arbitrary** phrase with no training. Chosen.

### Honest characterization of the technique
The recognizer is created with a **grammar constrained to the wake phrase only**:

```
["hey aura", "[unk]"]
```

Because decoding is restricted to that tiny grammar, the engine behaves as an
acoustic keyword spotter: **mic PCM → acoustic model inference → phrase +
per-word confidence**. It is **not** the fallback’s “free-form STT transcript →
substring search”. Trade-off vs. a dedicated single-phrase neural KWS
(Porcupine/openWakeWord): the Vosk model is larger and slightly heavier at
idle. A dedicated micro-KWS model is noted as future work.

---

## 2. Where the model lives in the source

```
android/app/src/main/assets/vosk-model-small-en-us-0.15/
  ├─ am/final.mdl
  ├─ graph/{HCLr.fst, Gr.fst, ...}
  ├─ ivector/{...}
  ├─ conf/{mfcc.conf, model.conf}
  ├─ README                    (upstream)
  └─ AURA_MODEL_LICENSE.txt    (added: source + Apache-2.0 notice)
```

It is a **native Android asset** (read by JNI/Kotlin), so no `pubspec.yaml`
asset entry is required. Gradle keeps the binary blobs uncompressed via
`androidResources { noCompress ... }` so the one-time unpack is a straight copy.

---

## 3. How inference works (native pipeline)

File: `android/app/src/main/kotlin/com/aura/aura_assistant/AuraAudioBridge.kt`

1. **initialize** (`com.aura.aura_assistant/wake` → `initialize`):
   checks `RECORD_AUDIO`, checks the asset exists, copies the model out of APK
   assets into internal storage once (`filesDir`, guarded by a `.unpacked`
   marker), then `Model(path)`. Returns exactly one of:
   `listening` (loaded) · `model_missing` (no asset) · `unavailable`
   (no mic permission / load failure). **Never faked.**
2. **start**: creates `Recognizer(model, 16000f, "[\"hey aura\", \"[unk]\"]")`
   with `setWords(true)` and enables the **shared** mic capture.
3. **capture loop** (single daemon thread): reads 512-sample (~32 ms) frames
   from ONE `AudioRecord` and feeds `recognizer.acceptWaveForm(buf, n)`.
4. On a finalized result, `phraseConfidence()` parses the JSON, confirms the
   text contains `hey aura`, and averages the per-word `conf` of `hey`+`aura`.
5. If `conf >= 0.55` (native pre-gate) **and** outside the native cooldown, a
   `{ "confidence": <real value> }` event is emitted; the recognizer is reset.

### Input format
16 kHz · mono · 16-bit PCM · 512-sample frames · `AudioSource.VOICE_COMMUNICATION`
(so the platform voice pipeline + AEC/NS apply). No normalization games, no
synthetic audio — raw device PCM straight into the model.

---

## 4. Detection threshold, debounce & cooldown

- **Native pre-gate:** confidence `>= 0.55`; native cooldown `2000 ms`.
- **Dart gate** (`lib/core/audio/wake_word_debouncer.dart`, reused, unchanged):
  `minConfidence = 0.5`, `cooldown = 2500 ms`, one-utterance-one-wake.

Two independent gates mean one spoken “Hey AURA” fires the session exactly once,
repeats inside the window are suppressed, and low-confidence noise is dropped.

---

## 5. Microphone pipeline (NO duplicate mic)

The wake KWS and the barge-in VAD now **share ONE `AudioRecord`** inside
`AuraAudioBridge`. The capture loop runs while *either* consumer is active and
tears down when *both* stop (reference-counted `micVadEnabled` / `wakeEnabled`).
AEC (`AcousticEchoCanceler`) + `NoiseSuppressor` are attached once to that
session. This is **additive** — the existing `output_level` (Visualizer) and
`mic_vad` channels are unchanged in name and payload shape.

---

## 6. Lifecycle

- **Dart engine** (`NativeAcousticWakeWordEngine`): `initialize / start / stop /
  dispose`. `start` is a no-op when status is `modelMissing`/`unavailable`
  (never fakes listening).
- **Coordinator** (`VoiceSessionCoordinator`, unchanged logic): arms the engine
  only in **IDLE**; disarms when a session starts and re-arms on session end.
  Because wake listens **only in IDLE**, it cannot be triggered by AURA’s own
  TTS while SPEAKING. Preferred over STT; STT is used only if the engine is not
  `listening`.
- **Native dispose** (called from `MainActivity.onDestroy`): closes the
  recognizer + model and releases the shared capture / AEC / NS.

### Android background restrictions (honest boundary)
Wake listening is scoped to while the app has the engine **armed (IDLE)**. A
dedicated **foreground microphone service** for truly always-on / screen-off
background KWS is **NOT** wired in this change (that would be a new component,
outside “only fix the wake word”). `RECORD_AUDIO`,
`FOREGROUND_SERVICE_MICROPHONE`, and `MODIFY_AUDIO_SETTINGS` are already
declared, so wiring such a service later is unblocked. This is the one
remaining limitation — stated plainly, not hidden.

---

## 7. AURA-speaking / self-wake prevention (preserved)

Unchanged and intact: output monitoring (Visualizer RMS), AEC + NoiseSuppressor
on the capture session, echo-safe mic monitor, and automatic barge-in armed on
SPEAKING. Additionally, the engine only listens in IDLE, so AURA’s voice cannot
self-wake it. AEC is applied to the same session that feeds the KWS.

---

## 8. Fallback behavior

`WakeWordService` (STT keyword spotter) is **kept, not deleted**. The
coordinator uses it **only** when the acoustic engine is unavailable
(no model / unsupported platform). The UI does not reveal which path is active
(diagnostic/error states aside).

---

## 9. Tests

Added: `test/core/audio/acoustic_wake_word_engine_test.dart` — exercises the
REAL engine against a **mocked native KWS channel** (the platform boundary a
device would provide):

- model loads → `listening`; `ready` treated as listening
- **missing model** → `modelMissing`, and `start` issues no native `start`,
  emits nothing
- **missing plugin** → `unavailable`
- valid “Hey AURA” event → fires once with the real confidence
- **low-confidence** event → rejected
- **debounce/cooldown** → 3 events in-window → fires once
- **repeated** detection after cooldown → fires again
- **lifecycle** stop → native `stop` + no further events
- scalar (non-map) confidence payload accepted

Retained: `wake_word_debouncer_test`, `voice_activity_detector_test`,
`barge_in_controller_test`, `audio_signal_math_test`.

**Honesty:** microphone/AEC/Vosk on-device inference cannot run in this
sandbox, so there is **no** real-hardware integration test and none is claimed
as passing. The Dart tests validate the wiring, gating, and lifecycle only.
The Kotlin/Vosk path is **not** unit-tested here (no Android test host).

---

## 10. Source audit (no fakes)

Searched the wake path for `random`, `hardcoded true`, synthetic wake events,
transcript-only primary detection, fake model/confidence, and leftover primary
wake `TODO`s. **None present.** The only occurrences of the word “fake” are in
comments stating we do NOT fake. `model_missing`/`unavailable` are returned
honestly. Confidence values come from the model’s per-word `conf`.

---

## 11. Files changed / added

**Added**
- `android/app/src/main/assets/vosk-model-small-en-us-0.15/**` (model + license note)
- `test/core/audio/acoustic_wake_word_engine_test.dart`

**Modified**
- `android/app/src/main/kotlin/com/aura/aura_assistant/AuraAudioBridge.kt`
  (real Vosk KWS + shared single-mic capture)
- `android/app/build.gradle` (vosk-android dependency + `noCompress`)
- `lib/core/voice_session/voice_session_coordinator.dart` (docstring accuracy only)

**Unchanged** (reused): `AcousticWakeWordEngine` interface, `WakeWordDebouncer`,
`audio_providers.dart`, `WakeWordService` (fallback), `VoiceSessionProviders`,
output/mic/barge-in monitors, `MainActivity` registration, `pubspec.yaml`.

---

## 12. Build verification

`BUILD NOT VERIFIED` — no Flutter/Android SDK in this environment. Not run:
`flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk
--debug`. Static checks done: channel names/payloads match across Dart↔Kotlin,
Kotlin brace balance OK, no forbidden patterns, model asset present and
readable, Gradle dependency + `noCompress` added.

**To verify on a machine with the SDK (Flutter 3.47.1 / Dart 3.13.1 / JDK 17,
compileSdk 36 / targetSdk 34 / minSdk 23):**
```
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```
