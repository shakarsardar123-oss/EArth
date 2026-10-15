import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'backend.dart';
import 'colors.dart';
import 'history_screen.dart';
import 'live_screen.dart';
import 'scope.dart';
import 'strings.dart';
import 'widgets.dart';

class _Msg {
  _Msg(this.isUser, this.text, {this.fresh = false, this.files = const <String>[]});

  final bool isUser;
  final String text;
  final bool fresh;
  final List<String> files;
}

IconData _fileIcon(String mime) {
  if (mime.startsWith('audio/')) return Icons.audiotrack_outlined;
  if (mime.startsWith('image/')) return Icons.image_outlined;
  if (mime.startsWith('video/')) return Icons.movie_outlined;
  if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
  return Icons.insert_drive_file_outlined;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.conversationId, this.initialPrompt});

  final String? conversationId;
  final String? initialPrompt;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _ctl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Msg> _msgs = <_Msg>[];
  final List<UiAttachment> _pending = <UiAttachment>[];
  bool _thinking = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _init(UiScope.of(context).backend);
    }
  }

  Future<void> _init(TexoBackend backend) async {
    final String? id = widget.conversationId;
    backend.beginChat(id);
    if (id != null) {
      final List<UiMessage> list = await backend.messages(id);
      if (!mounted) return;
      setState(() {
        for (final UiMessage m in list) {
          _msgs.add(_Msg(m.isUser, m.text));
        }
      });
      _toBottom();
    }
    final String? prompt = widget.initialPrompt;
    if (prompt != null && prompt.isNotEmpty) {
      await _send(backend, prompt);
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(
    TexoBackend backend,
    String text, {
    List<UiAttachment> attachments = const <UiAttachment>[],
  }) async {
    setState(() {
      _msgs.add(_Msg(true, text, files: attachments.map((UiAttachment a) => a.name).toList()));
      _thinking = true;
    });
    _toBottom();
    String reply;
    try {
      reply = await backend.ask(
        text,
        conversationId: widget.conversationId,
        attachments: attachments,
      );
    } catch (e) {
      reply = '$e';
    }
    if (!mounted) return;
    setState(() {
      _msgs.add(_Msg(false, reply, fresh: true));
      _thinking = false;
    });
    _toBottom();
  }

  void _submit(TexoBackend backend) {
    final String text = _ctl.text.trim();
    if ((text.isEmpty && _pending.isEmpty) || _thinking) return;
    final UiStrings s = UiScope.of(context).s;
    final List<UiAttachment> files = List<UiAttachment>.of(_pending);
    _ctl.clear();
    setState(_pending.clear);
    _send(backend, text.isEmpty ? s.t('attachPrompt') : text, attachments: files);
  }

  Future<void> _pick(TexoBackend backend) async {
    final UiAttachment? a = await backend.pickAttachment();
    if (a == null || !mounted) return;
    setState(() => _pending.add(a));
  }

  Widget _pendingRow(UiStrings s) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: <Widget>[
          for (final UiAttachment a in _pending)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Container(
                padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
                decoration: BoxDecoration(
                  color: UiColors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: UiColors.cardShadow,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(_fileIcon(a.mime), size: 18, color: UiColors.violetText),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: UiColors.ink),
                      ),
                    ),
                    UiIconButton(
                      icon: Icons.close,
                      label: s.t('attachRemove'),
                      size: 16,
                      color: UiColors.inkSoft,
                      onTap: () => setState(() => _pending.remove(a)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _userBubble(String text, List<String> files) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: PopIn(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 292),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: UiColors.skyBubble,
            borderRadius: BorderRadiusDirectional.only(
              topStart: Radius.circular(22),
              topEnd: Radius.circular(22),
              bottomStart: Radius.circular(22),
              bottomEnd: Radius.circular(6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final String f in files)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.attach_file, size: 16, color: UiColors.skyInk),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          f,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: UiColors.skyInk),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                text,
                style: const TextStyle(fontSize: 16, height: 1.7, color: UiColors.skyInk),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aiBlock(TexoBackend backend, UiStrings s, _Msg m) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 326),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const TexoLogo(size: 28, radius: 8, shadow: false),
            const SizedBox(height: 8),
            RevealText(
              m.text,
              animate: m.fresh,
              style: const TextStyle(fontSize: 16, height: 1.85, color: UiColors.ink),
            ),
            Row(
              children: <Widget>[
                _action(Icons.copy, s.t('copy'), () => Clipboard.setData(ClipboardData(text: m.text))),
                _action(Icons.volume_up_outlined, s.t('read'), () => backend.speak(m.text)),
                _action(Icons.refresh, s.t('retry'), () => _retry(backend, m)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _retry(TexoBackend backend, _Msg m) {
    if (_thinking) return;
    final int i = _msgs.indexOf(m);
    for (int j = i - 1; j >= 0; j--) {
      if (_msgs[j].isUser) {
        _send(backend, _msgs[j].text);
        return;
      }
    }
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 40,
          child: Icon(icon, size: 19, color: UiColors.inkSoft),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiScope scope = UiScope.of(context);
    final UiStrings s = scope.s;
    final TexoBackend backend = scope.backend;
    final int extra = _thinking ? 1 : 0;
    return Scaffold(
      body: UiBackground(
        kind: 1,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: <Widget>[
                    UiIconButton(
                      icon: Icons.arrow_back_ios_new,
                      label: s.t('back'),
                      size: 22,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        s.t('chatTitle'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    UiIconButton(
                      icon: Icons.history,
                      label: s.t('historyTitle'),
                      size: 24,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (BuildContext _) => const HistoryScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  itemCount: _msgs.length + extra,
                  separatorBuilder: (BuildContext c, int i) => const SizedBox(height: 18),
                  itemBuilder: (BuildContext c, int i) {
                    if (i >= _msgs.length) {
                      return PopIn(
                        child: Row(
                          children: <Widget>[
                            const ThinkingRing(),
                            const SizedBox(width: 12),
                            Text(
                              s.t('working'),
                              style: const TextStyle(fontSize: 15, color: UiColors.violetText),
                            ),
                          ],
                        ),
                      );
                    }
                    final _Msg m = _msgs[i];
                    return m.isUser ? _userBubble(m.text, m.files) : _aiBlock(backend, s, m);
                  },
                ),
              ),
              if (_pending.isNotEmpty) _pendingRow(s),
              Container(
                height: 64,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: UiColors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Color(0x261E5096), blurRadius: 28, offset: Offset(0, 8)),
                  ],
                ),
                child: Row(
                  children: <Widget>[
                    UiIconButton(
                      icon: Icons.add,
                      label: s.t('attach'),
                      size: 26,
                      onTap: () => _pick(backend),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _ctl,
                        onSubmitted: (String _) => _submit(backend),
                        textInputAction: TextInputAction.send,
                        style: const TextStyle(fontSize: 17, color: UiColors.ink),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: s.t('ask'),
                          hintStyle: const TextStyle(color: UiColors.inkFaint),
                        ),
                      ),
                    ),
                    UiIconButton(
                      icon: Icons.arrow_upward,
                      label: s.t('send'),
                      size: 20,
                      color: Colors.white,
                      background: UiColors.violet,
                      onTap: () => _submit(backend),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(builder: (BuildContext _) => const LiveScreen()),
                      ),
                      child: Semantics(
                        button: true,
                        label: s.t('live'),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: UiColors.pill,
                          ),
                          child: const Icon(Icons.graphic_eq, size: 22, color: UiColors.pillInk),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
