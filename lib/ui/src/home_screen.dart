import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'backend.dart';
import 'chat_screen.dart';
import 'colors.dart';
import 'history_screen.dart';
import 'dark.dart';
import 'live_screen.dart';
import 'permissions_flow.dart';
import 'scope.dart';
import 'settings_screen.dart';
import 'strings.dart';
import 'widgets.dart';

void _push(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (BuildContext _) => page));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// A new opening line every time the home screen is created.
  final int _greetSeed = math.Random().nextInt(1000);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOnboard());
  }

  /// First start: ask for every permission, one screen at a time.
  Future<void> _maybeOnboard() async {
    if (!mounted) return;
    final Object backend = UiScope.of(context).backend;
    if (backend is! TexoPermissionsExtras) return;
    bool needs = false;
    try {
      needs = await backend.needsOnboarding();
    } catch (_) {}
    if (!needs || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext _) => PermissionsFlowScreen(extras: backend),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiScope scope = UiScope.of(context);
    final UiStrings s = scope.s;
    return Scaffold(
      drawer: const TexoDrawer(),
      body: UiBackground(
        kind: 0,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 0),
                child: Row(
                  children: <Widget>[
                    Builder(
                      builder: (BuildContext ctx) => UiIconButton(
                        icon: Icons.menu,
                        label: s.t('menu'),
                        size: 28,
                        onTap: () => Scaffold.of(ctx).openDrawer(),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      s.t('model'),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF3A3A40),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 22, color: Color(0xFF3A3A40)),
                    const Spacer(),
                    UiIconButton(
                      icon: Icons.edit_outlined,
                      label: s.t('newChat'),
                      size: 26,
                      onTap: () => _push(context, const ChatScreen()),
                    ),
                    const SizedBox(width: 6),
                    const TexoLogo(size: 42, radius: 12, shadow: false),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const PopIn(child: TexoLogo(size: 84, radius: 20)),
                    const SizedBox(height: 22),
                    PopIn(
                      delay: const Duration(milliseconds: 120),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          s.greetingAt(_greetSeed),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 31,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                            color: Color(0xFF111114),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: <Widget>[
                    MagicCard(
                      icon: Icons.play_circle_outline,
                      text: s.t('s1'),
                      delay: const Duration(milliseconds: 150),
                      onTap: () => _push(context, ChatScreen(initialPrompt: s.t('s1prompt'))),
                    ),
                    const SizedBox(height: 12),
                    MagicCard(
                      icon: Icons.photo_camera_outlined,
                      text: s.t('s2'),
                      delay: const Duration(milliseconds: 320),
                      onTap: () => _push(context, const LiveScreen()),
                    ),
                    const SizedBox(height: 12),
                    MagicCard(
                      icon: Icons.alarm,
                      text: s.t('s3'),
                      delay: const Duration(milliseconds: 490),
                      onTap: () => _push(context, ChatScreen(initialPrompt: s.t('s3prompt'))),
                    ),
                  ],
                ),
              ),
              Container(
                height: 78,
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: UiColors.white,
                  borderRadius: BorderRadius.circular(39),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Color(0x261E5096), blurRadius: 28, offset: Offset(0, 8)),
                  ],
                ),
                child: Row(
                  children: <Widget>[
                    UiIconButton(
                      icon: Icons.add,
                      label: s.t('attach'),
                      size: 30,
                      onTap: () => _push(context, const ChatScreen(startWithAttach: true)),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _push(context, const ChatScreen()),
                        child: Container(
                          height: 48,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            s.t('ask'),
                            style: const TextStyle(fontSize: 19, color: UiColors.inkFaint),
                          ),
                        ),
                      ),
                    ),
                    UiIconButton(
                      icon: Icons.mic_none,
                      label: s.t('mic'),
                      size: 26,
                      onTap: () => _push(context, const LiveScreen()),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _push(context, const LiveScreen()),
                      child: Semantics(
                        button: true,
                        label: s.t('live'),
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: UiColors.pill,
                          ),
                          child: const Icon(Icons.graphic_eq, size: 28, color: UiColors.pillInk),
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

/// Side menu: new chat, recent chats, settings.
class TexoDrawer extends StatelessWidget {
  const TexoDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final UiScope scope = UiScope.of(context);
    final UiStrings s = scope.s;
    return Drawer(
      width: 312,
      backgroundColor: UiColors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const TexoLogo(size: 40, radius: 11, shadow: false),
                  const SizedBox(width: 12),
                  Text(
                    s.t('brand'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  _push(context, const ChatScreen());
                },
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FD),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.add, size: 22, color: UiColors.pillInk),
                      const SizedBox(width: 12),
                      Text(
                        s.t('newChat'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: UiColors.pillInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      s.t('recent'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: UiColors.inkSoft,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.of(context).pop();
                      _push(context, const HistoryScreen());
                    },
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        s.t('seeAll'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: UiColors.violetText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: FutureBuilder<List<UiConversation>>(
                  future: scope.backend.conversations(),
                  builder: (BuildContext c, AsyncSnapshot<List<UiConversation>> snap) {
                    final List<UiConversation> list =
                        (snap.data ?? const <UiConversation>[]).take(6).toList();
                    return ListView(
                      padding: EdgeInsets.zero,
                      children: <Widget>[
                        for (final UiConversation conv in list)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              Navigator.of(context).pop();
                              _push(context, ChatScreen(conversationId: conv.id));
                            },
                            child: Container(
                              height: 48,
                              alignment: AlignmentDirectional.centerStart,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                conv.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              for (final UiExtraEntry e in scope.backend.extraEntries)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (BuildContext c) => UiUnfilter(child: e.builder(c))),
                    );
                  },
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: <Widget>[
                        Icon(e.icon, size: 22),
                        const SizedBox(width: 12),
                        Text(
                          s.isKu ? e.titleKu : e.titleEn,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).pop();
                  _push(context, const SettingsScreen());
                },
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.settings_outlined, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        s.t('settings'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
