import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texo/core/audio/acoustic_wake_word_engine.dart';
import 'package:texo/core/audio/wake_word_debouncer.dart';

/// Tests the REAL NativeAcousticWakeWordEngine wiring against a mocked native
/// KWS channel: model loading, missing model, valid "Hey AURA" detection,
/// low-confidence rejection, debounce/cooldown, repeated detection, and
/// lifecycle. We do NOT mock the engine itself — only the platform boundary
/// (the native Vosk runner), which is what a device would provide.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const controlName = 'test/wake';
  const eventName = 'test/wake.events';
  const codec = StandardMethodCodec();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // Native "initialize" reply, overridden per-test.
  late String initReply;
  final methodLog = <String>[];

  void installControlHandler({bool missingPlugin = false}) {
    messenger.setMockMethodCallHandler(const MethodChannel(controlName),
        (call) async {
      if (missingPlugin) {
        throw MissingPluginException('no impl');
      }
      methodLog.add(call.method);
      switch (call.method) {
        case 'initialize':
          return initReply;
        case 'start':
          return true;
        case 'stop':
          return true;
      }
      return null;
    });
    // EventChannel listen/cancel just succeed.
    messenger.setMockMethodCallHandler(const MethodChannel(eventName),
        (call) async => null);
  }

  Future<void> emitWake(Object payload) async {
    await messenger.handlePlatformMessage(
      eventName,
      codec.encodeSuccessEnvelope(payload),
      (_) {},
    );
  }

  NativeAcousticWakeWordEngine buildEngine({
    WakeWordDebouncer? debouncer,
    DateTime Function()? clock,
  }) {
    return NativeAcousticWakeWordEngine(
      eventChannel: const EventChannel(eventName),
      controlChannel: const MethodChannel(controlName),
      debouncer: debouncer,
      clock: clock,
    );
  }

  setUp(() {
    initReply = 'unavailable';
    methodLog.clear();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(const MethodChannel(controlName), null);
    messenger.setMockMethodCallHandler(const MethodChannel(eventName), null);
  });

  test('model loads -> status listening', () async {
    installControlHandler();
    initReply = 'listening';
    final engine = buildEngine();
    final status = await engine.initialize();
    expect(status, WakeEngineStatus.listening);
    await engine.dispose();
  });

  test('ready is treated as listening (model loaded)', () async {
    installControlHandler();
    initReply = 'ready';
    final engine = buildEngine();
    expect(await engine.initialize(), WakeEngineStatus.listening);
    await engine.dispose();
  });

  test('missing model -> modelMissing and start does NOT listen', () async {
    installControlHandler();
    initReply = 'model_missing';
    final engine = buildEngine();
    expect(await engine.initialize(), WakeEngineStatus.modelMissing);

    var fired = 0;
    final sub = engine.wakeStream.listen((_) => fired++);
    await engine.start();
    // No native start should be issued while the model is missing.
    expect(methodLog.contains('start'), isFalse);
    // Even a spurious event must not fire (we never subscribed).
    await emitWake({'confidence': 0.99});
    await Future<void>.delayed(Duration.zero);
    expect(fired, 0);
    await sub.cancel();
    await engine.dispose();
  });

  test('missing plugin -> unavailable', () async {
    installControlHandler(missingPlugin: true);
    final engine = buildEngine();
    expect(await engine.initialize(), WakeEngineStatus.unavailable);
    await engine.dispose();
  });

  test('valid "Hey AURA" detection fires wakeStream once', () async {
    installControlHandler();
    initReply = 'listening';
    final engine = buildEngine();
    await engine.initialize();

    final events = <WakeEvent>[];
    final sub = engine.wakeStream.listen(events.add);
    await engine.start();
    expect(methodLog.contains('start'), isTrue);

    await emitWake({'confidence': 0.92});
    await Future<void>.delayed(Duration.zero);

    expect(events.length, 1);
    expect(events.first.confidence, closeTo(0.92, 1e-9));
    await sub.cancel();
    await engine.dispose();
  });

  test('low-confidence detection is rejected', () async {
    installControlHandler();
    initReply = 'listening';
    // Debouncer default minConfidence 0.5.
    final engine = buildEngine();
    await engine.initialize();
    var fired = 0;
    final sub = engine.wakeStream.listen((_) => fired++);
    await engine.start();

    await emitWake({'confidence': 0.30});
    await Future<void>.delayed(Duration.zero);
    expect(fired, 0);
    await sub.cancel();
    await engine.dispose();
  });

  test('debounce/cooldown: repeated detections within cooldown fire once',
      () async {
    installControlHandler();
    initReply = 'listening';
    // Fixed clock so the two events fall inside the cooldown window.
    final fixed = DateTime(2026, 1, 1, 12, 0, 0);
    final engine = buildEngine(
      debouncer: WakeWordDebouncer(
        cooldown: const Duration(seconds: 3),
        minConfidence: 0.5,
      ),
      clock: () => fixed,
    );
    await engine.initialize();
    var fired = 0;
    final sub = engine.wakeStream.listen((_) => fired++);
    await engine.start();

    await emitWake({'confidence': 0.9});
    await emitWake({'confidence': 0.9});
    await emitWake({'confidence': 0.9});
    await Future<void>.delayed(Duration.zero);
    expect(fired, 1);
    await sub.cancel();
    await engine.dispose();
  });

  test('repeated detection after cooldown fires again', () async {
    installControlHandler();
    initReply = 'listening';
    var t = DateTime(2026, 1, 1, 12, 0, 0);
    final engine = buildEngine(
      debouncer: WakeWordDebouncer(
        cooldown: const Duration(seconds: 2),
        minConfidence: 0.5,
      ),
      clock: () => t,
    );
    await engine.initialize();
    var fired = 0;
    final sub = engine.wakeStream.listen((_) => fired++);
    await engine.start();

    await emitWake({'confidence': 0.9});
    await Future<void>.delayed(Duration.zero);
    // Advance past the cooldown.
    t = t.add(const Duration(seconds: 3));
    await emitWake({'confidence': 0.9});
    await Future<void>.delayed(Duration.zero);
    expect(fired, 2);
    await sub.cancel();
    await engine.dispose();
  });

  test('lifecycle: stop issues native stop and cancels the subscription',
      () async {
    installControlHandler();
    initReply = 'listening';
    final engine = buildEngine();
    await engine.initialize();
    var fired = 0;
    final sub = engine.wakeStream.listen((_) => fired++);
    await engine.start();
    await engine.stop();
    expect(methodLog.contains('stop'), isTrue);

    // After stop, native events should no longer reach the stream.
    await emitWake({'confidence': 0.99});
    await Future<void>.delayed(Duration.zero);
    expect(fired, 0);
    await sub.cancel();
    await engine.dispose();
  });

  test('numeric (non-map) confidence payloads are accepted', () async {
    installControlHandler();
    initReply = 'listening';
    final engine = buildEngine();
    await engine.initialize();
    final events = <WakeEvent>[];
    final sub = engine.wakeStream.listen(events.add);
    await engine.start();
    await emitWake(0.88); // scalar confidence
    await Future<void>.delayed(Duration.zero);
    expect(events.length, 1);
    expect(events.first.confidence, closeTo(0.88, 1e-9));
    await sub.cancel();
    await engine.dispose();
  });
}
