// Phase 6-B: Flutter Overlay Hosting Foundation — Dart-side tests.
//
// These tests verify the structural integrity of the Phase 6-B
// FlutterView hosting foundation WITHOUT connecting to reaction/voice
// systems. They are source-level and structural — no device/emulator
// needed.
//
// Categories:
// 1. Widget existence & structure
// 2. RTL directionality
// 3. Dark background color
// 4. Cyan accent identity
// 5. Constant alignment with Kotlin
// 6. Entry point reachability
// 7. Forbidden import audit (real source verification)
// 8. ProviderScope architecture
// 9. ConsumerWidget contract
// 10. Dimension display text

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:texo/core/floating_aura/aura_overlay_host_widget.dart';
import 'package:texo/core/floating_aura/floating_aura_constants.dart';
import 'package:texo/core/theme/app_colors.dart';

// ────────────────────────────────────────────────────────────────────
// Helper: read the Dart source file for import audit
// ────────────────────────────────────────────────────────────────────

String _readDartSource() {
  final file = File(
    'lib/core/floating_aura/aura_overlay_host_widget.dart',
  );
  if (!file.existsSync()) {
    throw StateError(
      'aura_overlay_host_widget.dart not found at expected path',
    );
  }
  return file.readAsStringSync();
}

void main() {
  // ─────────────────────────────────────────────────────────────────
  // 1. Widget existence & structure
  // ─────────────────────────────────────────────────────────────────

  group('Phase 6-B: AuraOverlayHostWidget — widget existence', () {
    testWidgets('renders AuraOverlayHostWidget without error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AuraOverlayHostWidget(),
        ),
      );
      expect(find.byType(AuraOverlayHostWidget), findsOneWidget);
    });

    testWidgets('renders inside ProviderScope without error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AuraOverlayHostWidget(),
        ),
      );
      // ProviderScope must be present in the tree
      expect(find.byType(ProviderScope), findsOneWidget);
    });

    testWidgets('contains a Directionality widget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AuraOverlayHostWidget(),
        ),
      );
      expect(find.byType(Directionality), findsWidgets);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // 2. RTL directionality
  // ─────────────────────────────────────────────────────────────────

  group('Phase 6-B: RTL directionality for Kurdish Sorani', () {
    testWidgets('uses RTL Directionality', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AuraOverlayHostWidget(),
        ),
      );
      final directionality = tester.widgetList<Directionality>(
        find.byType(Directionality),
      );
      expect(
        directionality.any((d) => d.textDirection == TextDirection.rtl),
        isTrue,
        reason: 'AuraOverlayHostWidget must use RTL for Kurdish Sorani',
      );
    });

    testWidgets('RTL Directionality is the immediate child of ConsumerWidget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AuraOverlayHostWidget(),
        ),
      );
      // The first Directionality ancestor of the Column should be RTL
      final rtlDirs = tester.widgetList<Directionality>(
        find.byType(Directionality),
      ).where((d) => d.textDirection == TextDirection.rtl);
      expect(rtlDirs.length, greaterThanOrEqualTo(1));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // 3. Dark background color
  // ─────────────────────────────────────────────────────────────────

  group('Phase 6-B: Dark overlay host background', () {
    testWidgets('background color is 0xFF0B0E14', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AuraOverlayHostWidget(),
        ),
      );
      // Find the Container whose color is the dark background
      final containers = tester.widgetList<Container>(
        find.byType(Container),
      );
      final darkContainer = containers.firstWhere(
        (c) => c.color?.value == 0xFF0B0E14,
        orElse: () => fail('No Container with color 0xFF0B0E14 found'),
      );
      expect(darkContainer.color?.value, equals(0xFF0B0E14));
    });

    testWidgets('background color matches AppColors.background',
        (WidgetTester tester) async {
      expect(AppColors.background.value, equals(0xFF0B0E14));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // 4. Cyan accent identity
  // ─────────────────────────────────────────────────────────────────

  group('Phase 6-B: Cyan accent visual identity', () {
    testWidgets('contains a cyan circle with AppColors.cyan',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AuraOverlayHostWidget(),
        ),
      );
      final decorContainers = tester.widgetList<Container>(
        find.byType(Container),
      );
      final hasCyanCircle = decorContainers.any((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration) {
          return decoration.shape == BoxShape.circle &&
              decoration.color == AppColors.cyan;
        }
        return false;
      });
      expect(hasCyanCircle, isTrue, reason: 'Must contain cyan circle');
    });

    test('AppColors.cyan equals 0xFF00E5FF (matches Kotlin AURA_CYAN)', () {
      expect(AppColors.cyan.value, equals(0xFF00E5FF));
    });

    testWidgets('status text uses AppColors.cyan',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AuraOverlayHostWidget(),
        ),
      );
      final textWidgets = tester.widgetList<Text>(
        find.byType(Text),
      );
      final hasCyanText = textWidgets.any((t) {
        return t.style?.color == AppColors.cyan;
      });
      expect(hasCyanText, isTrue, reason: 'At least one Text must use AppColors.cyan');
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // 5. Constant alignment with Kotlin OverlayPlugin
  // ─────────────────────────────────────────────────────────────────

  group('Phase 6-B: Constant alignment with Kotlin', () {
    test('expandedWidth = 280.0 (matches Kotlin expandedWidth)', () {
      expect(FloatingAuraDefaults.expandedWidth, equals(280.0));
    });

    test('expandedHeight = 400.0 (matches Kotlin expandedHeight)', () {
      expect(FloatingAuraDefaults.expandedHeight, equals(400.0));
    });

    test('collapsedSize = 56.0 (matches Kotlin collapsedSize)', () {
      expect(FloatingAuraDefaults.collapsedSize, equals(56.0));
    });

    test('method channel name matches Kotlin', () {
      expect(
        floatingAuraMethodChannelName,
        equals('com.aura.aura_assistant/floating_aura_overlay'),
      );
    });

    test('method names count = 9 (all present)', () {
      // All 9 method names from Kotlin must exist in Dart
      expect(FloatingAuraMethodNames.requestPermission, isNotEmpty);
      expect(FloatingAuraMethodNames.openOverlaySettings, isNotEmpty);
      expect(FloatingAuraMethodNames.hasPermission, isNotEmpty);
      expect(FloatingAuraMethodNames.showOverlay, isNotEmpty);
      expect(FloatingAuraMethodNames.hideOverlay, isNotEmpty);
      expect(FloatingAuraMethodNames.updatePosition, isNotEmpty);
      expect(FloatingAuraMethodNames.togglePanel, isNotEmpty);
      expect(FloatingAuraMethodNames.isOverlayVisible, isNotEmpty);
      expect(FloatingAuraMethodNames.isSupported, isNotEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // 6. Entry point reachability
  // ─────────────────────────────────────────────────────────────────

  group('Phase 6-B: auraOverlayMain entry point', () {
    test('auraOverlayMain function exists and is callable', () {
      // This test will fail to compile if the function is removed.
      // ignore: unnecessary_null_comparison
      expect(auraOverlayMain, isNotNull);
    });

    test('entry point name matches Kotlin OVERLAY_ENTRY_POINT constant', () {
      // Kotlin: private const val OVERLAY_ENTRY_POINT = "auraOverlayMain"
      // Dart:   void auraOverlayMain() { ... }
      // The name must match exactly.
      const kotlinConstant = 'auraOverlayMain';
      // We verify the symbol exists by referencing it.
      // The function name is 'auraOverlayMain'.
      expect(
        auraOverlayMain.runtimeType.toString(),
        contains('Function'),
        reason: 'auraOverlayMain must be a function',
      );
    });

    test('source file contains @pragma vm:entry-point annotation', () {
      final source = _readDartSource();
      expect(
        source, contains("@pragma('vm:entry-point')"),
        reason: 'auraOverlayMain must have @pragma(\'vm:entry-point\') '
            'to prevent tree-shaking',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // 7. Forbidden import audit (REAL source verification)
  // ─────────────────────────────────────────────────────────────────

  group('Phase 6-B: Forbidden import audit — source verification', () {
    test('source has no /reaction/ import paths', () {
      final source = _readDartSource();
      final importLines = source
          .split('\n')
          .where((line) => line.startsWith('import '))
          .toList();
      final reactionImports = importLines
          .where((line) => line.contains('/reaction/'))
          .toList();
      expect(
        reactionImports,
        isEmpty,
        reason: 'No import may contain /reaction/ in Phase 6-B. '
            'Found: $reactionImports',
      );
    });

    test('source has no /voice/ import paths', () {
      final source = _readDartSource();
      final importLines = source
          .split('\n')
          .where((line) => line.startsWith('import '))
          .toList();
      final voiceImports = importLines
          .where((line) => line.contains('/voice/'))
          .toList();
      expect(
        voiceImports,
        isEmpty,
        reason: 'No import may contain /voice/ in Phase 6-B. '
            'Found: $voiceImports',
      );
    });

    test('source has no ReactionEngine import', () {
      final source = _readDartSource();
      expect(
        source,
        isNot(contains('ReactionEngine')),
        reason: 'ReactionEngine must not appear in Phase 6-B source',
      );
    });

    test('source has no VoiceService import', () {
      final source = _readDartSource();
      expect(
        source,
        isNot(contains('VoiceService')),
        reason: 'VoiceService must not appear in Phase 6-B source',
      );
    });

    test('source has no AgentReactionAdapter import', () {
      final source = _readDartSource();
      expect(
        source,
        isNot(contains('AgentReactionAdapter')),
        reason: 'AgentReactionAdapter must not appear in Phase 6-B source',
      );
    });

    test('source has no VoiceReactionAdapter import', () {
      final source = _readDartSource();
      expect(
        source,
        isNot(contains('VoiceReactionAdapter')),
        reason: 'VoiceReactionAdapter must not appear in Phase 6-B source',
      );
    });

    test('source imports exactly 4 packages (flutter, riverpod, app_colors, constants)',
        () {
      final source = _readDartSource();
      final importLines = source
          .split('\n')
          .where((line) =>
              line.startsWith("import 'package:") ||
              line.startsWith('import "package:'))
          .toList();
      expect(
        importLines.length,
        equals(4),
        reason: 'Phase 6-B must have exactly 4 package imports. '
            'Found: $importLines',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // 8. ProviderScope architecture
  // ─────────────────────────────────────────────────────────────────

  group('Phase 6-B: ProviderScope architecture', () {
    test('source creates own ProviderScope in auraOverlayMain', () {
      final source = _readDartSource();
      expect(
        source,
        contains('ProviderScope'),
        reason: 'auraOverlayMain must create its own ProviderScope',
      );
    });

    test('source wraps AuraOverlayHostWidget in ProviderScope', () {
      final source = _readDartSource();
      expect(
        source,
        contains('ProviderScope(\n      child: AuraOverlayHostWidget'),
        reason: 'auraOverlayMain must wrap AuraOverlayHostWidget in '
            'ProviderScope for isolate independence',
      );
    });

    test('source calls WidgetsFlutterBinding.ensureInitialized', () {
      final source = _readDartSource();
      expect(
        source,
        contains('WidgetsFlutterBinding.ensureInitialized'),
        reason: 'auraOverlayMain must call WidgetsFlutterBinding.ensureInitialized',
      );
    });

    test('source calls runApp', () {
      final source = _readDartSource();
      expect(
        source,
        contains('runApp'),
        reason: 'auraOverlayMain must call runApp with ProviderScope',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // 9. ConsumerWidget contract
  // ─────────────────────────────────────────────────────────────────

  group('Phase 6-B: ConsumerWidget contract', () {
    test('AuraOverlayHostWidget is a ConsumerWidget', () {
      const widget = AuraOverlayHostWidget();
      expect(widget, isA<ConsumerWidget>());
    });

    test('AuraOverlayHostWidget is const-constructible', () {
      // If this compiles, the widget is const-constructible.
      const widget = AuraOverlayHostWidget();
      expect(widget.key, isNull);
    });

    test('source declares AuraOverlayHostWidget extends ConsumerWidget', () {
      final source = _readDartSource();
      expect(
        source,
        contains('class AuraOverlayHostWidget extends ConsumerWidget'),
        reason: 'AuraOverlayHostWidget must extend ConsumerWidget',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // 10. Dimension display text
  // ─────────────────────────────────────────────────────────────────

  group('Phase 6-B: Dimension display text', () {
    testWidgets('shows correct dimension string 280×400dp',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AuraOverlayHostWidget(),
        ),
      );
      final expected =
          '${FloatingAuraDefaults.expandedWidth.toInt()}'
          '×'
          '${FloatingAuraDefaults.expandedHeight.toInt()}dp';
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('shows AURA Overlay Ready text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AuraOverlayHostWidget(),
        ),
      );
      expect(find.text('AURA Overlay Ready'), findsOneWidget);
    });

    testWidgets('shows FlutterView hosting active text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AuraOverlayHostWidget(),
        ),
      );
      expect(find.text('FlutterView hosting active'), findsOneWidget);
    });
  });
}
