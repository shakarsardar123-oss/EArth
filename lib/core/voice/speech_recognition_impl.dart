/// speech_recognition_impl.dart
/// AURA / TEXO – Offline Sorani speech recognition.
///
/// Uses the native Vekol Whisper-based Sorani STT engine through
/// TexoAudioBridge. No Android SpeechRecognizer and no speech_to_text
/// dependency are used.
///
/// Public API intentionally remains compatible with the previous service
/// so existing AURA call-sites do not need to change.
library;

import '../phone_agent/debug_toast.dart';
import 'cloud_stt.dart';
import 'dart:async';

import 'package:flutter/services.dart';

class SpeechRecognitionServiceImpl {
  static const MethodChannel _channel =
      MethodChannel('com.texo.texo/stt');

  static const EventChannel _events =
      EventChannel('com.texo.texo/stt.events');

  bool _initialized = false;
  bool _listening = false;
  StreamSubscription<dynamic>? _eventSubscription;

  void Function(String text)? _onResult;
  void Function(String text)? _onPartial;
  void Function(double level)? _onSoundLevel;

  Future<bool> initialize() async {
    if (_initialized) return true;

    // The Vekol engine is initialized natively on first inference.
    // There is no device speech-recognition service to initialize.
    _initialized = true;
    return true;
  }

  Future<void> startListening({
    required void Function(String text) onResult,
    void Function(String text)? onPartial,
    void Function(double level)? onSoundLevel,
    String? locale = 'ckb_IQ',
  }) async {
    if (!_initialized) {
      await initialize();
    }

    await stopListening();

    _onResult = onResult;
    _onPartial = onPartial;
    _onSoundLevel = onSoundLevel;

    _eventSubscription = _events.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is! Map) return;

        final type = event['type'];

        switch (type) {
          case 'speechStarted':
            debugToast('STT: speech started');
            // Native VAD detected the beginning of speech.
            break;

          case 'processing':
            debugToast('STT: processing');
            // Vekol inference is running.
            break;

          case 'utterance':
            // Cloud mode: the native side hands over the finished sentence as WAV.
            final id = event['id'];
            final wav = event['wav'];
            if (id is int && wav is String) {
              unawaited(_transcribeInCloud(id, wav));
            }
            break;

          case 'result':
            debugToast('STT result: "${event['text']}"');
            final text = event['text'];
            if (text is String && text.trim().isNotEmpty) {
              _onResult?.call(text.trim());
            }
            break;

          case 'error':
            final message = event['message'] ?? 'Unknown native STT error';
            print('[AURA STT ERROR] $message');
            debugToast('STT ERROR: $message');
            break;
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        print('[AURA STT STREAM ERROR] $error');
        debugToast('STT STREAM ERROR: $error');
      },
      cancelOnError: false,
    );

    try {
      await _channel.invokeMethod<bool>(
        'setCloud',
        await CloudStt.instance.available(),
      );
    } catch (_) {}

    final started = await _channel.invokeMethod<bool>('start');

    if (started != true) {
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      debugToast('STT: failed to start');
      throw StateError('Failed to start native Vekol STT');
    }

    _listening = true;
  }

  Future<void> _transcribeInCloud(int id, String wav) async {
    final String? text = await CloudStt.instance.transcribe(wav);
    if (!_listening) return;
    if (text == null) {
      // No internet / key / timeout: use the on-device model instead.
      try {
        await _channel.invokeMethod<bool>('local', <String, Object?>{'id': id});
      } catch (_) {}
      return;
    }
    if (text.isNotEmpty) _onResult?.call(text);
  }

  Future<void> stopListening() async {
    if (_listening) {
      try {
        await _channel.invokeMethod<bool>('stop');
      } catch (_) {
        // Keep shutdown best-effort, matching the old service behavior.
      }
    }

    _listening = false;

    await _eventSubscription?.cancel();
    _eventSubscription = null;

    _onResult = null;
    _onPartial = null;
    _onSoundLevel = null;
  }

  Future<void> dispose() async {
    await stopListening();
  }
}
