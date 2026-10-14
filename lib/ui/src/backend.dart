import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

enum LiveMode { listening, thinking, speaking }

class UiMessage {
  const UiMessage({required this.isUser, required this.text});

  final bool isUser;
  final String text;
}

class UiConversation {
  const UiConversation({
    required this.id,
    required this.title,
    required this.snippet,
    required this.time,
  });

  final String id;
  final String title;
  final String snippet;
  final DateTime time;
}

/// What the Live visual reads every frame. The real app updates these
/// notifiers from the microphone level, the TTS level and the live-mode state.
class LiveVoiceSource {
  LiveVoiceSource({LiveMode initial = LiveMode.listening})
      : mode = ValueNotifier<LiveMode>(initial),
        level = ValueNotifier<double>(0.0),
        content = ValueNotifier<ui.Image?>(null),
        caption = ValueNotifier<String>('');

  /// listening / thinking / speaking.
  final ValueNotifier<LiveMode> mode;

  /// Voice level 0..1 (microphone while listening, TTS while speaking).
  final ValueNotifier<double> level;

  /// Image shown inside the water orb while the answer is spoken (map, photo).
  final ValueNotifier<ui.Image?> content;

  /// Question while listening, answer text while speaking.
  final ValueNotifier<String> caption;

  void dispose() {
    mode.dispose();
    level.dispose();
    content.dispose();
    caption.dispose();
  }
}

/// Everything the new UI needs from the app logic. The UI package has no
/// dependency on providers: the app supplies one implementation of this.
abstract class TexoBackend {
  String get userName;

  LiveVoiceSource get liveSource;

  Future<void> startLive();
  Future<void> stopLive();
  Future<void> toggleMic();

  Future<String> ask(String text, {String? conversationId});
  Future<void> speak(String text);

  Future<List<UiConversation>> conversations();
  Future<List<UiMessage>> messages(String conversationId);

  Future<Map<String, bool>> toggles();
  Future<void> setToggle(String key, bool value);

  Future<Map<String, bool>> permissionStates();
  Future<void> openPermission(String key);

  Future<bool> hasApiKey();
  Future<void> setApiKey(String key);
}
