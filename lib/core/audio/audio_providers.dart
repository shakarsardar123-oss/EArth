/// audio_providers.dart
/// AURA Assistant – Final Voice Phase: Riverpod wiring for the real audio
/// pipeline (output level, echo-safe mic + AEC, acoustic wake word, barge-in).
///
/// Each provider picks the NATIVE implementation on Android and the safe STUB
/// elsewhere (or in tests / when the platform channel is missing). Nothing
/// here fabricates audio — the stubs fail closed to silence / unavailable.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'acoustic_wake_word_engine.dart';
import 'barge_in_controller.dart';
import 'echo_safe_mic_monitor.dart';
import 'output_level_monitor.dart';

bool get _isAndroid => !kIsWeb && Platform.isAndroid;

/// Real AURA output-audio-level monitor (Visualizer RMS on Android).
final outputLevelMonitorProvider = Provider<OutputLevelMonitor>((ref) {
  final monitor =
      _isAndroid ? NativeOutputLevelMonitor() : StubOutputLevelMonitor();
  ref.onDispose(() {
    if (monitor is NativeOutputLevelMonitor) monitor.dispose();
  });
  return monitor;
});

/// Echo-safe mic monitor (single AudioRecord + AcousticEchoCanceler on
/// Android). Shared by the barge-in controller.
final echoSafeMicMonitorProvider = Provider<EchoSafeMicMonitor>((ref) {
  final monitor =
      _isAndroid ? NativeEchoSafeMicMonitor() : StubEchoSafeMicMonitor();
  ref.onDispose(() {
    if (monitor is NativeEchoSafeMicMonitor) monitor.dispose();
  });
  return monitor;
});

/// Automatic barge-in controller built on the shared echo-safe mic monitor.
final bargeInControllerProvider = Provider<BargeInController>((ref) {
  final controller =
      BargeInController(micMonitor: ref.watch(echoSafeMicMonitorProvider));
  ref.onDispose(controller.dispose);
  return controller;
});

/// Genuine acoustic wake-word engine (native KWS; reports modelMissing until
/// a "Hey AURA" model asset is bundled). Stub elsewhere.
final acousticWakeWordEngineProvider =
    Provider<AcousticWakeWordEngine>((ref) {
  final engine =
      _isAndroid ? NativeAcousticWakeWordEngine() : StubAcousticWakeWordEngine();
  ref.onDispose(engine.dispose);
  return engine;
});
