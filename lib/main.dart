/// main.dart
/// AURA Assistant – P1 Fix: Gemini-First App Entry
///
/// UPDATED: Gemini is now the primary AI provider.
/// - Instantiates both GeminiProvider and OpenAIProvider.
/// - Overrides both geminiProviderProvider and openaiProviderProvider.
/// - Gemini is the default (user can switch in settings).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'core/localization/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/ai/ai_connection_storage.dart';
import 'core/ai/openai_provider.dart' show OpenAIProvider;
import 'core/ai/gemini_provider.dart' show GeminiProvider;
import 'presentation/providers/app_providers.dart';
import 'presentation/screens/main_shell.dart';
import 'services/notifications/alarm_notification_service.dart';
import 'presentation/providers/alarm_providers.dart';
import 'core/alarm/wake_verification_service.dart';
import 'presentation/screens/wake_alarm_screen.dart';

/// Global navigator key for alarm notification tap navigation.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final secureStorage = const FlutterSecureStorage();

  final connectionStorage = AIConnectionStorage(
    secureStorage: secureStorage,
    sharedPreferences: prefs,
  );

  // One-time, idempotent migration of the legacy Gemini chat default
  // (gemini-1.5-flash) to the current default (gemini-3.6-flash).
  // No-op for OpenAI connections and user-chosen custom Gemini models.
  await connectionStorage.migrateLegacyGeminiDefaultModel();

  // ── Gemini (primary/default) ─────────────────────────────
  final geminiProvider = GeminiProvider(
    secureStorage: secureStorage,
    connectionStorage: connectionStorage,
  );

  // ── OpenAI (secondary) ───────────────────────────────────
  final openaiProvider = OpenAIProvider(
    secureStorage: secureStorage,
    connectionStorage: connectionStorage,
  );

  // Wire notification tap callback for alarm navigation.
  AlarmNotificationService.onActionCallback = (String payload) {
    if (payload.isNotEmpty) {
      final alarmListNotifier = _globalRef?.read(alarmListProvider.notifier);
      if (alarmListNotifier != null) {
        // Find alarm by ID from payload
        final alarms = _globalRef!.read(alarmListProvider);
        final alarm = alarms.where((a) => a.id == payload).firstOrNull;
        if (alarm != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => WakeAlarmScreen(alarm: alarm),
            ),
          );
        }
      }
    }
  };

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        flutterSecureStorageProvider.overrideWithValue(secureStorage),
        aiConnectionStorageProvider.overrideWithValue(connectionStorage),
        geminiProviderProvider.overrideWithValue(geminiProvider),
        openaiProviderProvider.overrideWithValue(openaiProvider),
      ],
      child: const AuraApp(),
    ),
  );
}

/// Stored WidgetRef for alarm notification callback access.
WidgetRef? _globalRef;

/// AuraApp converted to StatefulWidget + WidgetsBindingObserver
/// to handle isolate bridge (pending_alarm_id) on app resume.
class AuraApp extends ConsumerStatefulWidget {
  const AuraApp({super.key});

  @override
  ConsumerState<AuraApp> createState() => _AuraAppState();
}

class _AuraAppState extends ConsumerState<AuraApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _globalRef = ref;

    // Start the Step 24 platform-trigger runtime consumer.
    ref.read(triggerRuntimeServiceProvider).start();
  }

  @override
  void dispose() {
    ref.read(triggerRuntimeServiceProvider).stop();
    WidgetsBinding.instance.removeObserver(this);
    _globalRef = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      // Isolate bridge: check if a pending alarm ID was written
      // by the static _alarmCallback running in a separate isolate.
      final prefs = await SharedPreferences.getInstance();
      final pendingId = prefs.getString('pending_alarm_id');
      if (pendingId != null && pendingId.isNotEmpty) {
        // Clear the pending flag immediately.
        await prefs.remove('pending_alarm_id');

        // Find the alarm and trigger verification.
        final alarms = ref.read(alarmListProvider);
        final alarm = alarms.where((a) => a.id == pendingId).firstOrNull;
        if (alarm != null) {
          final wakeService = ref.read(wakeVerificationProvider);
          await wakeService.triggerAlarm(alarm);

          // Navigate to alarm screen.
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => WakeAlarmScreen(alarm: alarm),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(overriddenThemeProvider);
    final locale = ref.watch(overriddenLocaleProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'TEXO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode.toThemeMode(),
      locale: locale.toLocale(),
      supportedLocales: AuraLocale.values.map((l) => l.toLocale()),
      localizationsDelegates: S.localizationsDelegates,
      // Kurdish (Sorani, 'ku') is NOT in Flutter's built-in RTL language
      // table, so GlobalWidgetsLocalizations resolves it to LTR. Wrapping
      // only `home` in a Directionality left every *pushed* route, dialog,
      // bottom sheet and SnackBar rendering LTR while the home screen was
      // RTL. Applying the app-locale direction through MaterialApp.builder
      // forces the correct direction for the ENTIRE navigator subtree
      // (all routes + overlays), fixing the mixed-direction breakage.
      builder: (context, child) => Directionality(
        textDirection: locale.textDirection,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const MainShell(),
    );
  }
}
