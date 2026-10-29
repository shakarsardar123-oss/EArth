import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show AppBar, Icons, Scaffold, Theme;
import 'package:flutter/services.dart' show EventChannel, MethodChannel;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/agent/agent_context.dart';
import '../core/ai/ai_message.dart';
import '../core/live_mode/live_mode_providers.dart';
import '../core/live_mode/live_mode_state.dart';
import '../core/localization/locale_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/voice/voice_service_provider.dart';
import '../domain/services/ai_service.dart';
import '../domain/entities/agent_config.dart';
import '../presentation/providers/app_providers.dart';
import '../presentation/screens/vision_screen.dart';
import '../presentation/widgets/api_key_settings_section.dart';
import '../presentation/widgets/permissions_section.dart';
import '../ui/texo_ui.dart';
import '../ui/src/backend.dart'
    show TexoCameraExtras, TexoPermissionsExtras, TexoPickExtras, UiPermissionItem;
import 'live_camera.dart';
import 'overlay_controller.dart';

/// Connects the new UI ([TexoBackend]) to the existing app logic (Riverpod).
class RiverpodBackend
    implements TexoBackend, TexoCameraExtras, TexoPermissionsExtras, TexoPickExtras {
  RiverpodBackend(this._c) {
    Future<void>.microtask(_initWake);
  }

  final ProviderContainer _c;
  final LiveVoiceSource _live = LiveVoiceSource();
  final LiveCamera _cam = LiveCamera();
  late final OverlayController _overlay = OverlayController(onAction: _onOverlayAction);
  int _ovTick = 0;
  bool _micOff = false;
  bool _muted = false;
  bool _subs = false;
  String _lastYou = '';
  String _lastAi = '';
  bool _translateOn = false;
  String _translatedSubtitle = '';
  String _lastCaptionSource = '';
  int _translationGeneration = 0;
  Timer? _subtitleClearTimer;
  StreamSubscription<double>? _ttsSub;
  double _ttsLevel = 0;
  int _ttsAt = 0;
  bool _muteStopped = false;
  bool _liveRunning = false;
  Future<void> _tail = Future<void>.value();
  String _lastPushKey = '';
  int _lastPushAt = 0;

  /// Start / stop of Live Mode run one after another, so quick taps can never
  /// start and stop it at the same time.
  Future<void> _serial(Future<void> Function() job) {
    final Future<void> next = _tail.then((_) => job()).catchError((Object _) {});
    _tail = next;
    return next;
  }

  String? _convId;
  Timer? _levelTimer;
  ProviderSubscription<LiveModeState>? _liveSub;
  final Stopwatch _sw = Stopwatch();

  // ---- language -------------------------------------------------------------

  String get initialLang => _c.read(overriddenLocaleProvider).code;

  void setLang(String lang) {
    _c
        .read(overriddenLocaleProvider.notifier)
        .setLocale(lang == 'en' ? AuraLocale.en : AuraLocale.ku);
  }

  // ---- identity ---------------------------------------------------------------

  @override
  List<UiExtraEntry> get extraEntries => <UiExtraEntry>[
        UiExtraEntry(
          titleKu: 'بینین',
          titleEn: 'Vision',
          icon: Icons.visibility_outlined,
          builder: (BuildContext context) =>
              Theme(data: AppTheme.dark(), child: VisionScreen()),
        ),
        UiExtraEntry(
          titleKu: 'ئەی ئای (دابینکەر و مۆدێل)',
          titleEn: 'AI provider and model',
          icon: Icons.smart_toy_outlined,
          builder: (BuildContext context) => Theme(
            data: AppTheme.dark(),
            child: const TexoExtraPage(title: 'AI', child: ApiKeySettingsSection()),
          ),
        ),
        UiExtraEntry(
          titleKu: 'ڕێگەپێدانەکان',
          titleEn: 'Permissions',
          icon: Icons.verified_user_outlined,
          builder: (BuildContext context) => Theme(
            data: AppTheme.dark(),
            child: const TexoExtraPage(title: 'Permissions', child: PermissionsSection()),
          ),
        ),
      ];

  @override
  String get userName {
    final String? saved = _c.read(sharedPreferencesProvider).getString('user_name');
    return (saved != null && saved.trim().isNotEmpty) ? saved.trim() : 'شاکار';
  }

  // ---- chat ---------------------------------------------------------------------

  @override
  void beginChat(String? conversationId) {
    _convId = conversationId;
  }

  static String _short(String s, int n) {
    final String t = s.replaceAll('\n', ' ').trim();
    return t.length > n ? '${t.substring(0, n)}…' : t;
  }

  static String _mimeFor(String name, String? ext) {
    final String e = (ext ?? name.split('.').last).toLowerCase();
    const Map<String, String> m = <String, String>{
      'wav': 'audio/wav',
      'mp3': 'audio/mp3',
      'm4a': 'audio/mp4',
      'aac': 'audio/aac',
      'ogg': 'audio/ogg',
      'oga': 'audio/ogg',
      'opus': 'audio/ogg',
      'flac': 'audio/flac',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'webp': 'image/webp',
      'heic': 'image/heic',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'md': 'text/plain',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      '3gp': 'video/3gpp',
    };
    return m[e] ?? 'application/octet-stream';
  }

  @override
  Future<UiAttachment?> pickAttachment() async {
    final FilePickerResult? r = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (r == null || r.files.isEmpty) return null;
    final PlatformFile f = r.files.first;
    var bytes = f.bytes;
    if (bytes == null && f.path != null) {
      bytes = await File(f.path!).readAsBytes();
    }
    if (bytes == null) return null;
    return UiAttachment(name: f.name, mime: _mimeFor(f.name, f.extension), bytes: bytes);
  }

  @override
  Future<UiAttachment?> pickKind(String kind) async {
    const int maxBytes = 15 * 1024 * 1024;
    const String tooBig = 'فایلەکە زۆر گەورەیە (زۆرترین ١٥ مێگابایت)';
    if (kind == 'camera') {
      final XFile? x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2048,
      );
      if (x == null) return null;
      if (await x.length() > maxBytes) throw tooBig;
      return UiAttachment(name: x.name, mime: _mimeFor(x.name, null), bytes: await x.readAsBytes());
    }
    FileType type = FileType.any;
    List<String>? exts;
    if (kind == 'image') {
      type = FileType.image;
    } else if (kind == 'video') {
      type = FileType.video;
    } else if (kind == 'audio') {
      type = FileType.audio;
    } else if (kind == 'pdf') {
      type = FileType.custom;
      exts = <String>['pdf'];
    }
    final FilePickerResult? r = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: exts,
      allowMultiple: false,
      withData: false,
    );
    if (r == null || r.files.isEmpty) return null;
    final PlatformFile f = r.files.first;
    if (f.size > maxBytes) throw tooBig;
    var bytes = f.bytes;
    if (bytes == null && f.path != null) {
      bytes = await File(f.path!).readAsBytes();
    }
    if (bytes == null) return null;
    return UiAttachment(name: f.name, mime: _mimeFor(f.name, f.extension), bytes: bytes);
  }

  @override
  Future<String> ask(
    String text, {
    String? conversationId,
    List<UiAttachment> attachments = const <UiAttachment>[],
  }) async {
    final memory = _c.read(memoryServiceProvider);
    String? convId = _convId ?? conversationId;
    try {
      convId ??= await memory.createConversation(title: _short(text, 40), agentId: 'default');
      _convId = convId;
    } catch (_) {}

    final List<Map<String, String>> history = <Map<String, String>>[];
    final List<AIMessage> historyMsgs = <AIMessage>[];
    if (convId != null) {
      try {
        for (final m in await memory.getMessages(convId)) {
          final bool user = m.role == 'user';
          history.add(<String, String>{'role': user ? 'user' : 'assistant', 'content': m.content});
          historyMsgs.add(AIMessage(
            role: user ? AIMessageRole.user : AIMessageRole.assistant,
            content: m.content,
          ));
        }
      } catch (_) {}
    }

    String reply;
    bool ok = true;
    try {
      if (attachments.isNotEmpty) {
        int total = 0;
        for (final UiAttachment a in attachments) {
          total += a.bytes.length;
        }
        if (total > 15 * 1024 * 1024) {
          return 'فایلەکە زۆر گەورەیە. سنووری ١٥ مێگابایتە.';
        }
        final provider = _c.read(selectedAIProviderProvider);
        final msg = AIMessage(
          role: AIMessageRole.user,
          content: text,
          metadata: <String, dynamic>{
            'attachments': <Map<String, String>>[
              for (final UiAttachment a in attachments)
                <String, String>{'mime': a.mime, 'name': a.name, 'data': base64Encode(a.bytes)},
            ],
          },
        );
        final res = await provider.complete(AIRequest(
          prompt: text,
          agentConfig: _c.read(agentConfigProvider),
          messages: <AIMessage>[...historyMsgs, msg],
        ));
        reply = res.text;
      } else {
        final result = await _c.read(agentEngineProvider).run(
              userInput: text,
              context: AgentContext(
                agentConfig: _c.read(agentConfigProvider),
                conversationHistory: history,
                maxSteps: 10,
              ),
            );
        ok = result.isSuccess && result.response != null;
        reply = ok
            ? result.response!
            : (result.errorMessage ?? 'ببورە، نەمتوانم وەڵام بدەمەوە.');
      }
    } catch (e) {
      ok = false;
      reply = 'ببورە، هەڵەیەک ڕوویدا: $e';
    }

    if (ok && convId != null) {
      try {
        await memory.addMessage(conversationId: convId, role: 'user', content: text);
        await memory.addMessage(conversationId: convId, role: 'assistant', content: reply);
      } catch (_) {}
    }
    return reply;
  }

  @override
  Future<void> speak(String text) async {
    await _c.read(voiceServiceImplProvider).speak(text);
  }

  @override
  Future<List<UiConversation>> conversations() async {
    final memory = _c.read(memoryServiceProvider);
    final List<String> ids = await memory.getConversationIds(limit: 40);
    final List<UiConversation> out = <UiConversation>[];
    for (final String id in ids) {
      final msgs = await memory.getMessages(id);
      if (msgs.isEmpty) continue;
      final first = msgs.firstWhere((m) => m.role == 'user', orElse: () => msgs.first);
      final last = msgs.last;
      out.add(UiConversation(
        id: id,
        title: _short(first.content, 46),
        snippet: _short(last.content, 60),
        time: last.createdAt ?? first.createdAt ?? DateTime.now(),
      ));
    }
    return out;
  }

  @override
  Future<List<UiMessage>> messages(String conversationId) async {
    final msgs = await _c.read(memoryServiceProvider).getMessages(conversationId);
    return <UiMessage>[
      for (final m in msgs) UiMessage(isUser: m.role == 'user', text: m.content),
    ];
  }

  // ---- settings -----------------------------------------------------------------

  static const Map<String, bool> _toggleDefaults = <String, bool>{
    'wake': true,
    'read': true,
    'hap': false,
  };

  @override
  Future<Map<String, bool>> toggles() async {
    final prefs = _c.read(sharedPreferencesProvider);
    return <String, bool>{
      for (final MapEntry<String, bool> e in _toggleDefaults.entries)
        e.key: prefs.getBool('ui.toggle.${e.key}') ?? e.value,
    };
  }

  @override
  Future<void> setToggle(String key, bool value) async {
    await _c.read(sharedPreferencesProvider).setBool('ui.toggle.$key', value);
    if (key == 'wake') {
      if (value) {
        unawaited(_tryStartWake());
      } else {
        await _stopWake();
      }
    }
  }

  @override
  Future<Map<String, bool>> permissionStates() async {
    bool overlay = false;
    try {
      overlay = await Permission.systemAlertWindow.isGranted;
    } catch (_) {}
    // TODO: real accessibility-service status.
    return <String, bool>{'overlay': overlay, 'access': false};
  }

  @override
  Future<void> openPermission(String key) async {
    if (key == 'overlay') {
      await Permission.systemAlertWindow.request();
    } else {
      // TODO: open the Accessibility settings screen.
      await openAppSettings();
    }
  }

  @override
  Future<bool> hasApiKey() async {
    // The key of the provider that is actually selected (Gemini OR OpenAI),
    // the same one the "AI provider and model" page edits.
    final Object? k = await _c.read(selectedAIProviderProvider).getApiKey();
    return k is String && k.trim().isNotEmpty;
  }

  @override
  Future<void> setApiKey(String key) async {
    await _c.read(selectedAIProviderProvider).setApiKey(key.trim());
  }

  // ---- live ---------------------------------------------------------------------

  @override
  LiveVoiceSource get liveSource => _live;

  void _applyState(LiveModeState s) {
    _live.mode.value = s == LiveModeState.processing
        ? LiveMode.thinking
        : (s == LiveModeState.speaking ? LiveMode.speaking : LiveMode.listening);
    _cam.capturing = _live.mode.value == LiveMode.listening;
    if (_muted && _live.mode.value == LiveMode.speaking && !_muteStopped) {
      _muteStopped = true;
      _c.read(voiceServiceImplProvider).stopSpeaking();
    }
    if (_live.mode.value != LiveMode.speaking) _muteStopped = false;
    _pushOverlay();
  }

  // ---- wake word ("texo") -----------------------------------------------------

  static const MethodChannel _wakeCh = MethodChannel('com.texo.texo/wake');
  static const EventChannel _wakeEv = EventChannel('com.texo.texo/wake.events');
  StreamSubscription<dynamic>? _wakeSub;
  Timer? _wakeRetry;
  bool _wakeOn = false; // the native listener is running
  bool _overlayOnly = false; // this live session was started by the wake word

  bool get _wakeWanted =>
      _c.read(sharedPreferencesProvider).getBool('ui.toggle.wake') ?? true;

  Future<void> _initWake() async {
    _wakeRetry ??= Timer.periodic(const Duration(seconds: 20), (Timer _) => _tryStartWake());
    await _tryStartWake();
  }

  Future<void> _tryStartWake() async {
    if (_wakeOn || _liveRunning || !_wakeWanted) return;
    try {
      if (!await Permission.microphone.isGranted) return;
      _wakeSub ??= _wakeEv.receiveBroadcastStream().listen(
        (dynamic _) => _onWake(),
        onError: (Object _) {},
      );
      final Object? ok = await _wakeCh.invokeMethod<Object?>('start');
      _wakeOn = ok == true;
    } catch (_) {}
  }

  Future<void> _stopWake() async {
    if (!_wakeOn) return;
    _wakeOn = false;
    try {
      await _wakeCh.invokeMethod<Object?>('stop');
    } catch (_) {}
  }

  /// "texo" was heard: only the overlay appears and the live conversation starts.
  Future<void> _onWake() async {
    if (_liveRunning || !_wakeWanted) return;
    _overlayOnly = true;
    _overlay.forceVisible = true;
    await _serial(_startLive);
  }

  @override
  Future<void> startLive() {
    _overlayOnly = false;
    _overlay.forceVisible = false;
    return _serial(_startLive);
  }

  Future<void> _startLive() async {
    if (_liveRunning) return;
    final PermissionStatus st = await Permission.microphone.request();
    if (!st.isGranted) return;
    await _stopWake();
    _liveRunning = true;
    _micOff = false;
    _muted = false;
    _liveSub?.close();
    _liveSub = _c.listen<LiveModeState>(
      liveModeStateProvider,
      (LiveModeState? prev, LiveModeState next) => _applyState(next),
      fireImmediately: true,
    );
    _sw
      ..reset()
      ..start();
    _levelTimer?.cancel();
    _levelTimer = Timer.periodic(const Duration(milliseconds: 16), (Timer _) => _tickLevel());
    _live.active.value = true;
    _lastYou = '';
    _lastAi = '';
    _live.caption.value = '';
    _ttsSub?.cancel();
    _ttsSub = _c.read(voiceServiceImplProvider).speakingLevelStream.listen((double v) {
      _ttsLevel = v.clamp(0.0, 1.0).toDouble();
      _ttsAt = DateTime.now().millisecondsSinceEpoch;
    });
    await _overlay.start();
    _pushFlags();
    final orchestrator = _c.read(liveModeOrchestratorProvider);
    orchestrator.onScreenCaption = _handleScreenCaption;
    orchestrator.onUserRecognized = (String text) {
      _lastYou = text;
      _live.caption.value = text;
      _pushOverlay();
    };
    orchestrator.onAIResponse = (String text) {
      final String clean = text.split('```').first.trim();
      _lastAi = clean;
      _live.caption.value = clean;
      _pushOverlay();
    };
    orchestrator.onSessionEnded = (String reason) {
      _live.active.value = false;
      // No Live screen is open (wake-word session): close the overlay too.
      if (_overlayOnly) stopLive();
    };
    await orchestrator.startSession();
    // The old live-mode code may have registered its own overlay handler or
    // shown the pill while the app is visible: take both back.
    _overlay.rebind();
    await _overlay.syncVisibility();
  }

  Future<void> _handleScreenCaption(String rawText) async {
    if (!_translateOn) return;

    final String source = rawText.trim();
    if (source.isEmpty || source == _lastCaptionSource) return;
    _lastCaptionSource = source;
    final int requestId = ++_translationGeneration;

    try {
      final provider = _c.read(selectedAIProviderProvider);
      final String modelId = provider.supportedModels.isNotEmpty
          ? provider.supportedModels.first
          : 'default';
      final response = await provider.complete(
        AIRequest(
          prompt: 'Translate this visible video subtitle into natural '
              'Sorani Kurdish (Central Kurdish). Preserve the meaning and '
              'tone. Output only the translation, with no explanation.\n\n'
              'Subtitle: $source',
          agentConfig: AgentConfig.defaultConfig.copyWith(
            id: 'subtitle_translation',
            name: 'Subtitle Translation',
            description: 'Translate visible video captions into Sorani.',
            systemPrompt: 'You are a subtitle translation engine. Translate '
                'into natural Sorani Kurdish (Central Kurdish), using Kurdish '
                'Arabic script. Output only the translated text.',
            modelId: modelId,
            temperature: 0.2,
            maxTokens: 256,
          ),
          temperature: 0.2,
          maxTokens: 256,
        ),
      );

      if (!_translateOn || requestId != _translationGeneration) return;
      final String translated = response.text.trim();
      if (translated.isEmpty) return;

      _translatedSubtitle = translated;
      _pushTranslationOverlay();
      _subtitleClearTimer?.cancel();
      _subtitleClearTimer = Timer(const Duration(seconds: 5), () {
        if (requestId != _translationGeneration) return;
        _translatedSubtitle = '';
        _pushTranslationOverlay();
      });
    } catch (_) {
      // Translation failures must not interrupt Live Mode.
    }
  }

  void _pushTranslationOverlay() {
    _overlay.push(<String, Object?>{
      'trans': _translateOn,
      'translatedSubtitle': _translatedSubtitle,
    });
  }

  /// Until real microphone / TTS levels are connected, the level is a gentle
  /// speech-like envelope that depends on the live-mode state.
  void _tickLevel() {
    final double t = _sw.elapsedMilliseconds / 1000.0;
    final LiveMode m = _live.mode.value;
    final double phr = math.pow(math.max(0.0, math.sin(t * 0.85)), 0.7).toDouble();
    final double syl = 0.5 + 0.5 * math.sin(t * 6.3 + math.sin(t * 1.7) * 2);
    double v;
    if (m == LiveMode.speaking) {
      final bool real = DateTime.now().millisecondsSinceEpoch - _ttsAt < 300;
      v = real ? 0.10 + 0.85 * _ttsLevel : 0.12 + 0.75 * phr * (0.40 + 0.60 * syl);
    } else if (m == LiveMode.thinking) {
      v = 0.10 + 0.04 * math.sin(t * 2);
    } else {
      v = 0.08 + 0.05 * math.sin(t * 1.3);
    }
    _live.level.value = v;
    if (++_ovTick % 5 == 0) _pushOverlay();
  }

  @override
  Future<void> stopLive() => _serial(_stopLive);

  Future<void> _stopLive() async {
    ++_translationGeneration;
    _subtitleClearTimer?.cancel();
    _translatedSubtitle = '';
    _liveRunning = false;
    _levelTimer?.cancel();
    _levelTimer = null;
    _liveSub?.close();
    _liveSub = null;
    _live.level.value = 0;
    await _cam.stop();
    await _overlay.stop();
    await _ttsSub?.cancel();
    _ttsSub = null;
    try {
      await _c.read(liveModeOrchestratorProvider).stopSession();
    } catch (_) {}
    _overlayOnly = false;
    _overlay.forceVisible = false;
    // Back to waiting for "texo" once the microphone is free.
    Future<void>.delayed(const Duration(milliseconds: 900), _tryStartWake);
  }

  String _emoji(LiveMode m) {
    if (m == LiveMode.thinking) return '\u{1F914}';
    if (m == LiveMode.speaking) {
      const List<String> e = <String>['\u{1F604}', '\u{1F62E}', '\u{1F3B5}', '\u{1F970}'];
      return e[(DateTime.now().millisecondsSinceEpoch ~/ 2200) % e.length];
    }
    return '\u{1F642}';
  }

  void _pushOverlay() {
    final LiveMode m = _live.mode.value;
    final double level = (_live.level.value * 20).round() / 20.0;
    final String emoji = _emoji(m);
    final int now = DateTime.now().millisecondsSinceEpoch;
    final String key = '$m|$level|$emoji|$initialLang|$_lastYou|$_lastAi|'
        '$_translateOn|$_translatedSubtitle';
    // Only talk to the native overlay when something changed (plus a
    // keep-alive once a second): far fewer platform-channel calls.
    if (key == _lastPushKey && now - _lastPushAt < 1000) return;
    _lastPushKey = key;
    _lastPushAt = now;
    _overlay.push(<String, Object?>{
      'mode': m == LiveMode.thinking ? 'thinking' : (m == LiveMode.speaking ? 'speaking' : 'listening'),
      'level': level,
      'emoji': emoji,
      'lang': initialLang,
      'you': _lastYou,
      'ai': _lastAi,
      'trans': _translateOn,
      'translatedSubtitle': _translatedSubtitle,
    });
  }

  /// The toggles (mic, mute, subtitles) are only sent when they change: the
  /// native overlay owns them while the user taps its buttons.
  void _pushFlags() {
    _overlay.push(<String, Object?>{
      'micOff': _micOff,
      'muted': _muted,
      'subs': _subs,
      'trans': _translateOn,
      'translatedSubtitle': _translatedSubtitle,
    });
  }

  void _onOverlayAction(String action) {
    final int eq = action.indexOf('=');
    final String name = eq >= 0 ? action.substring(0, eq) : action;
    final bool? value = eq >= 0 ? action.substring(eq + 1) == '1' : null;
    switch (name) {
      case 'close':
        _live.active.value = false;
        stopLive();
        break;
      case 'mic':
        // Real switch: off = the assistant does not listen at all.
        _micOff = value ?? !_micOff;
        unawaited(_c.read(liveModeOrchestratorProvider).setMicPaused(_micOff));
        _pushFlags();
        break;
      case 'mute':
        _muted = value ?? !_muted; // best effort: speech is stopped whenever the assistant starts talking
        _c.read(liveModeOrchestratorProvider).speechMuted = _muted;
        if (_muted) _c.read(voiceServiceImplProvider).stopSpeaking();
        _pushFlags();
        break;
      case 'subs':
        _subs = value ?? !_subs;
        _pushFlags();
        break;
      case 'translate':
        _translateOn = value ?? !_translateOn;
        ++_translationGeneration;
        _lastCaptionSource = '';
        _subtitleClearTimer?.cancel();
        if (!_translateOn) _translatedSubtitle = '';
        unawaited(_c.read(liveModeOrchestratorProvider).setScreenTranslation(_translateOn));
        _pushFlags();
        _pushOverlay();
        break;
      default:
        break; // translate / guide / tray_open / tray_close / hide / show: later
    }
  }

  @override
  ValueListenable<bool> get cameraActive => _cam.active;

  @override
  Future<void> setCamera(bool on) => on ? _cam.start() : _cam.stop();

  @override
  Future<void> switchCamera() => _cam.switchCamera();

  @override
  Widget? buildCameraPreview() => _cam.preview();

  // ---- first-run permissions ---------------------------------------------------

  static const MethodChannel _sysCh = MethodChannel('com.texo.texo/floating_texo_overlay');
  static const MethodChannel _sttCh = MethodChannel('com.texo.texo/stt');

  /// Ends the running recording now (the user finished speaking).
  Future<void> _finishUtterance() async {
    try {
      await _sttCh.invokeMethod<Object?>('finish');
    } catch (_) {}
  }

  @override
  List<UiPermissionItem> get permissionItems => const <UiPermissionItem>[
        UiPermissionItem(
          id: 'mic',
          icon: Icons.mic_none,
          titleKu: 'مایکرۆفۆن',
          titleEn: 'Microphone',
          bodyKu: 'بۆ ئەوەی گوێم لە دەنگت بێت و لێت تێبگەم.',
          bodyEn: 'So I can hear you and understand you.',
        ),
        UiPermissionItem(
          id: 'notifications',
          icon: Icons.notifications_none,
          titleKu: 'ئاگادارکردنەوە',
          titleEn: 'Notifications',
          bodyKu: 'بۆ ئەلارم و ئاگادارکردنەوەکان، و بۆ ئەوەی ئۆڤەرلای TEXO بتوانێت کار بکات.',
          bodyEn: 'For alarms and reminders, and so the TEXO overlay can run.',
        ),
        UiPermissionItem(
          id: 'camera',
          icon: Icons.photo_camera_outlined,
          titleKu: 'کامێرا',
          titleEn: 'Camera',
          bodyKu: 'بۆ ئەوەی ئەوەی دەیبینیت ببینم و ڕوونی بکەمەوە.',
          bodyEn: 'So I can see what you show me and explain it.',
        ),
        UiPermissionItem(
          id: 'overlay',
          icon: Icons.layers_outlined,
          titleKu: 'پەنجەرەی سەر ئەپەکان',
          titleEn: 'Display over other apps',
          bodyKu: 'بۆ ئەوەی کاتێک لە ئەپێکی تر دەبیت، TEXO بەسەر شاشەکەتەوە دەربکەوێت. لە لیستەکەدا TEXO هەڵبژێرە و چالاکی بکە.',
          bodyEn: 'So TEXO can appear on top of other apps. Pick TEXO in the list and switch it on.',
        ),
        UiPermissionItem(
          id: 'accessibility',
          icon: Icons.touch_app_outlined,
          titleKu: 'دەستڕاگەیشتن بە شاشە',
          titleEn: 'Screen access',
          bodyKu: 'بۆ ئەوەی ئەپەکان بکەمەوە، شاشە بخوێنمەوە و لێدانەکان بۆت بکەم. لە لیستەکەدا TEXO هەڵبژێرە و چالاکی بکە. ئەگەر خۆڵەمێشی بوو: زانیاری ئەپ ← سێ خاڵ ← Allow restricted settings.',
          bodyEn: 'So I can open apps, read the screen and tap for you. Pick TEXO in the list and switch it on. If it is greyed out: App info > three dots > Allow restricted settings.',
        ),
      ];

  @override
  Future<bool> permissionGranted(String id) async {
    switch (id) {
      case 'mic':
        return Permission.microphone.isGranted;
      case 'notifications':
        return Permission.notification.isGranted;
      case 'camera':
        return Permission.camera.isGranted;
      case 'overlay':
        final Object? ro = await _sysCh.invokeMethod<Object?>('hasPermission');
        return ro is Map && ro['granted'] == true;
      case 'accessibility':
        final Object? ra = await _sysCh.invokeMethod<Object?>('isAccessibilityEnabled');
        return ra == true;
    }
    return false;
  }

  @override
  Future<void> requestPermission(String id) async {
    switch (id) {
      case 'mic':
        await Permission.microphone.request();
        break;
      case 'notifications':
        await Permission.notification.request();
        break;
      case 'camera':
        await Permission.camera.request();
        break;
      case 'overlay':
        await _sysCh.invokeMethod<Object?>('requestPermission');
        break;
      case 'accessibility':
        await _sysCh.invokeMethod<Object?>('openAccessibilitySettings');
        break;
    }
  }

  @override
  Future<bool> needsOnboarding() async =>
      _c.read(sharedPreferencesProvider).getBool('texo_onboarded') != true;

  @override
  Future<void> finishOnboarding() async {
    await _c.read(sharedPreferencesProvider).setBool('texo_onboarded', true);
  }

  @override
  ValueListenable<bool> get torchOn => _cam.torchOn;

  @override
  ValueListenable<bool> get cameraIsFront => _cam.isFront;

  @override
  Future<void> toggleTorch() => _cam.toggleTorch();

  @override
  Future<void> toggleMic() => _finishUtterance();
}

/// A plain page that hosts one of the old settings sections.
class TexoExtraPage extends StatelessWidget {
  const TexoExtraPage({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}
