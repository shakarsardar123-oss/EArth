import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/phase3_connection_points.dart' show navigationIndexProvider;
import '../widgets/security_confirmation_host.dart';
import '../widgets/floating_nav_bar.dart';
import 'chat_screen.dart';
import 'voice_screen.dart';
import 'settings_screen.dart';

/// Main Shell — consolidated to 3 tabs.
///
/// Tab mapping (navIndex → screen):
///   0 = VoiceScreen (Home — Wave Form)
///   1 = ChatScreen
///   2 = SettingsScreen
///
/// Profile tab removed (was duplicate of Settings).
/// DashboardScreen removed from tab nav (greeting logic moved to VoiceScreen).
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navigationIndexProvider).clamp(0, 2);

    // 3 tabs matching nav bar items: Home, Chat, Settings
    final screens = <Widget>[
      const VoiceScreen(),
      const ChatScreen(),
      const SettingsScreen(),
    ];

    return SecurityConfirmationHost(
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: index,
          children: screens,
        ),
        bottomNavigationBar: const FloatingNavBar(),
      ),
    );
  }
}