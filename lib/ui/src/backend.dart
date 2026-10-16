import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Widget;

enum LiveMode { listening, thinking, speaking }

class UiMessage {
  const UiMessage({required this.isUser, required this.text});

  final bool isUser;
  final String text;
}

/// A file the user attaches to a message (audio, image, PDF, text...).
class UiAttachment {
  const UiAttachment({required this.name, required this.mime, required this.bytes});

  final String name;
  final String mime;
  final Uint8List bytes;
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
        caption = ValueNotifier<String>(''),
        active = ValueNotifier<bool>(true);

  /// listening / thinking / speaking.
  final ValueNotifier<LiveMode> mode;

  /// Voice level 0..1 (microphone while listening, TTS while speaking).
  final ValueNotifier<double> level;

  /// Image shown inside the water orb while the answer is spoken (map, photo).
  final ValueNotifier<ui.Image?> content;

  /// Question while listening, answer text while speaking.
  final ValueNotifier<String> caption;

  /// Becomes false when the session was ended from outside the Live screen
  /// (for example by the floating overlay's close button).
  final ValueNotifier<bool> active;

  void dispose() {
    mode.dispose();
    level.dispose();
    content.dispose();
    caption.dispose();
    active.dispose();
  }
}

/// Everything the new UI needs from the app logic. The UI package has no
/// dependency on providers: the app supplies one implementation of this.
abstract class TexoBackend {
  String get userName;

  LiveVoiceSource get liveSource;

  /// Called when a chat screen opens: [conversationId] null = brand new chat.
  void beginChat(String? conversationId);

  Future<void> startLive();
  Future<void> stopLive();
  Future<void> toggleMic();

  /// Live camera: true while the camera is on. The app attaches the current
  /// frame to what the user says, so the assistant can "see".
  ValueListenable<bool> get cameraActive;
  Future<void> setCamera(bool on);
  Future<void> switchCamera();

  /// The live camera preview, or null when the camera is off. Fills its parent.
  Widget? buildCameraPreview();

  /// Opens the system file picker. Returns null if the user cancels.
  Future<UiAttachment?> pickAttachment();

  Future<String> ask(
    String text, {
    String? conversationId,
    List<UiAttachment> attachments = const <UiAttachment>[],
  });
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
