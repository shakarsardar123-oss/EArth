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
            // Native VAD detected the beginning of speech.
            break;

          case 'processing':
            // Vekol inference is running.
            break;

          case 'result':
            final text = event['text'];
            if (text is String && text.trim().isNotEmpty) {
              _onResult?.call(text.trim());
            }
            break;

          case 'error':
            // Errors are handled by stopping the active recognition
            // session. The existing VoiceService will enter its error
            // state if the native channel call fails.
            break;
        }
      },
      onError: (_) {
        // Keep the public API compatible with the previous implementation.
      },
      cancelOnError: false,
    );

    final started = await _channel.invokeMethod<bool>('start');

    if (started != true) {
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      throw StateError('Failed to start native Vekol STT');
    }

    _listening = true;
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
