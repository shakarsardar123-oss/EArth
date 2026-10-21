import 'package:flutter/material.dart';

import 'backend.dart';
import 'chat_screen.dart';
import 'colors.dart';
import 'live_painter.dart';
import 'scope.dart';
import 'settings_screen.dart';
import 'strings.dart';
import 'widgets.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _frame =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  LivePainter? _painter;
  TexoBackend? _backend;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_painter == null) {
      final TexoBackend backend = UiScope.of(context).backend;
      _backend = backend;
      _painter = LivePainter(backend.liveSource, repaint: _frame);
      backend.liveSource.active.value = true;
      backend.liveSource.active.addListener(_onActive);
      backend.startLive();
    }
  }

  void _onActive() {
    final TexoBackend? b = _backend;
    if (b != null && !b.liveSource.active.value && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    _backend?.liveSource.active.removeListener(_onActive);
    _backend?.setCamera(false);
    _backend?.stopLive();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiScope scope = UiScope.of(context);
    final UiStrings s = scope.s;
    final LiveVoiceSource src = scope.backend.liveSource;
    final double top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: UiColors.liveTop,
      body: UiBackground(
        kind: 2,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: _painter),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: scope.backend.cameraActive,
              builder: (BuildContext c, bool on, Widget? _) {
                if (!on) return const SizedBox.shrink();
                final Widget? view = scope.backend.buildCameraPreview();
                if (view == null) return const SizedBox.shrink();
                final Object ob = scope.backend;
                final TexoCameraExtras? ex = ob is TexoCameraExtras ? ob : null;
                return Positioned.fill(
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ClipRect(child: view),
                      // Front camera "flash": a bright screen light.
                      if (ex != null)
                        AnimatedBuilder(
                          animation: Listenable.merge(<Listenable>[ex.torchOn, ex.cameraIsFront]),
                          builder: (BuildContext c2, Widget? _) {
                            final bool light = ex.torchOn.value && ex.cameraIsFront.value;
                            return IgnorePointer(
                              child: ColoredBox(
                                color: light ? const Color(0xB3FFFFFF) : const Color(0x00FFFFFF),
                              ),
                            );
                          },
                        ),
                      // A soft shade at the bottom keeps the buttons readable.
                      const Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          height: 260,
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[Color(0x00000000), Color(0x99000000)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            SafeArea(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        GlassCircle(
                          icon: Icons.arrow_back_ios_new,
                          label: s.t('back'),
                          size: 44,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Column(
                            children: <Widget>[
                              Text(
                                s.t('brand'),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w500,
                                  color: UiColors.liveInk,
                                ),
                              ),
                              ValueListenableBuilder<LiveMode>(
                                valueListenable: src.mode,
                                builder: (BuildContext c, LiveMode m, Widget? _) {
                                  final String key = m == LiveMode.thinking
                                      ? 'thinking'
                                      : (m == LiveMode.speaking ? 'speaking' : 'listening');
                                  return Text(
                                    s.t(key),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.6,
                                      color: UiColors.liveSoft,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        GlassCircle(
                          icon: Icons.more_vert,
                          label: s.t('settings'),
                          size: 44,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (BuildContext _) => const SettingsScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(30, 0, 30, 24),
                    child: ValueListenableBuilder<String>(
                      valueListenable: src.caption,
                      builder: (BuildContext c, String text, Widget? _) => Text(
                        text.isEmpty ? s.t('hint') : text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, height: 1.8, color: UiColors.liveSoft),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        GlassCircle(
                          icon: Icons.chat_bubble_outline,
                          label: s.t('chatTitle'),
                          onTap: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(builder: (BuildContext _) => const ChatScreen()),
                          ),
                        ),
                        const SizedBox(width: 18),
                        ValueListenableBuilder<bool>(
                          valueListenable: scope.backend.cameraActive,
                          builder: (BuildContext c, bool on, Widget? _) => GlassCircle(
                            icon: on ? Icons.videocam : Icons.videocam_off_outlined,
                            label: s.t('camera'),
                            active: on,
                            onTap: () => scope.backend.setCamera(!on),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Semantics(
                          button: true,
                          label: s.t('mic'),
                          child: GestureDetector(
                            onTap: () => scope.backend.toggleMic(),
                            child: Container(
                              width: 74,
                              height: 74,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(color: Color(0x388B5CF6), spreadRadius: 7),
                                  BoxShadow(
                                    color: Color(0x8C8B5CF6),
                                    blurRadius: 34,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.mic, size: 30, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        GlassCircle(
                          icon: Icons.close,
                          label: s.t('close'),
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: scope.backend.cameraActive,
              builder: (BuildContext c, bool on, Widget? _) {
                if (!on) return const SizedBox.shrink();
                final Object ob = scope.backend;
                final TexoCameraExtras? ex = ob is TexoCameraExtras ? ob : null;
                return PositionedDirectional(
                  top: top + 72,
                  end: 20,
                  child: Column(
                    children: <Widget>[
                      GlassCircle(
                        icon: Icons.cameraswitch_outlined,
                        label: s.t('cameraFlip'),
                        size: 40,
                        onTap: () => scope.backend.switchCamera(),
                      ),
                      if (ex != null) ...<Widget>[
                        const SizedBox(height: 12),
                        ValueListenableBuilder<bool>(
                          valueListenable: ex.torchOn,
                          builder: (BuildContext c2, bool lit, Widget? _) => GlassCircle(
                            icon: lit ? Icons.flash_on : Icons.flash_off,
                            label: s.t('flash'),
                            size: 40,
                            active: lit,
                            onTap: () => ex.toggleTorch(),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
