import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/audio/barge_in_controller.dart';
import 'package:aura_assistant/core/audio/echo_safe_mic_monitor.dart';
import 'package:aura_assistant/core/audio/voice_activity_detector.dart';

/// Fake mic monitor whose frames we drive by hand — tests the REAL integration
/// boundary (monitor → VAD → controller → onBargeIn), not a mocked success.
class FakeMicMonitor implements EchoSafeMicMonitor {
  final _controller = StreamController<MicFrame>.broadcast();
  bool started = false;
  AecStatus _aec;
  FakeMicMonitor([this._aec = AecStatus.active]);

  void emit(double level, {double zcr = 0.5}) =>
      _controller.add(MicFrame(level: level, zcr: zcr));

  @override
  Stream<MicFrame> get frameStream => _controller.stream;
  @override
  AecStatus get aecStatus => _aec;
  @override
  bool get isRunning => started;
  @override
  Future<AecStatus> start() async {
    started = true;
    return _aec;
  }
  @override
  Future<void> stop() async {
    started = false;
  }
  Future<void> dispose() async => _controller.close();
}

void main() {
  group('BargeInController', () {
    test('fires onBargeIn on a confirmed speech onset', () async {
      final mic = FakeMicMonitor();
      final ctrl = BargeInController(
        micMonitor: mic,
        vad: VoiceActivityDetector(energyThreshold: 0.1, startFrames: 3),
      );
      var fired = 0;
      ctrl.onBargeIn = () => fired++;

      await ctrl.arm();
      expect(mic.started, isTrue);

      mic.emit(0.5);
      mic.emit(0.5);
      mic.emit(0.5);
      await Future<void>.delayed(Duration.zero);
      expect(fired, 1);

      await ctrl.dispose();
      await mic.dispose();
    });

    test('does NOT fire on isolated amplitude spikes', () async {
      final mic = FakeMicMonitor();
      final ctrl = BargeInController(
        micMonitor: mic,
        vad: VoiceActivityDetector(energyThreshold: 0.1, startFrames: 3),
      );
      var fired = 0;
      ctrl.onBargeIn = () => fired++;
      await ctrl.arm();

      mic.emit(0.9);
      mic.emit(0.0);
      mic.emit(0.9);
      mic.emit(0.0);
      await Future<void>.delayed(Duration.zero);
      expect(fired, 0);

      await ctrl.dispose();
      await mic.dispose();
    });

    test('disarm stops the mic and ignores later frames', () async {
      final mic = FakeMicMonitor();
      final ctrl = BargeInController(
        micMonitor: mic,
        vad: VoiceActivityDetector(energyThreshold: 0.1, startFrames: 1),
      );
      var fired = 0;
      ctrl.onBargeIn = () => fired++;
      await ctrl.arm();
      await ctrl.disarm();
      expect(mic.started, isFalse);

      mic.emit(0.9);
      await Future<void>.delayed(Duration.zero);
      expect(fired, 0);

      await mic.dispose();
    });

    test('surfaces AEC status from the monitor', () async {
      final mic = FakeMicMonitor(AecStatus.unavailable);
      final ctrl = BargeInController(micMonitor: mic);
      expect(ctrl.aecStatus, AecStatus.unavailable);
      await mic.dispose();
    });
  });
}
