/// realistic_globe_perf_test.dart
/// RUNTIME widget tests for RealisticGlobe's frame architecture.
///
/// These run headlessly under `flutter test` (no GPU). They cannot measure
/// on-device FPS, but they DO prove the behaviours that the perf claims rest
/// on at runtime:
///   1. The globe pumps many animation frames without throwing.
///   2. A RepaintBoundary wraps the CustomPaint (paint is layer-isolated).
///   3. The surrounding screen does NOT rebuild on idle spin frames
///      (the ticker mutates state and repaints WITHOUT setState).
///   4. A controller highlight updates the Semantics label at runtime.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura_assistant/features/globe/application/globe_controller.dart';
import 'package:aura_assistant/features/globe/domain/globe_models.dart';
import 'package:aura_assistant/features/globe/presentation/realistic_globe.dart';

void main() {
  group('RealisticGlobe frame architecture (runtime)', () {
    testWidgets('spins across many frames without throwing', (tester) async {
      final controller = GlobeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RealisticGlobe(controller: controller, size: 200),
            ),
          ),
        ),
      );

      // Advance ~120 frames of idle spin (~2s at 60fps). A continuously
      // repeating animation never settles, so we pump discrete frames.
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(tester.takeException(), isNull);
      expect(find.byType(RealisticGlobe), findsOneWidget);

      // Unmount to dispose the ticker cleanly.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('wraps paint in a RepaintBoundary', (tester) async {
      final controller = GlobeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RealisticGlobe(controller: controller, size: 160),
            ),
          ),
        ),
      );

      final boundary = find.descendant(
        of: find.byType(RealisticGlobe),
        matching: find.byType(RepaintBoundary),
      );
      expect(boundary, findsWidgets);
      expect(
        find.descendant(
          of: find.byType(RealisticGlobe),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('idle spin does NOT rebuild the surrounding screen',
        (tester) async {
      final controller = GlobeController();
      addTearDown(controller.dispose);

      var screenBuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                screenBuilds++;
                return Center(
                  child: RealisticGlobe(controller: controller, size: 200),
                );
              },
            ),
          ),
        ),
      );

      final buildsAfterMount = screenBuilds;

      // Pump ~90 idle frames; the ticker advances the globe every frame.
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // The screen's build closure must not have run again for spin frames.
      expect(screenBuilds, buildsAfterMount,
          reason: 'Idle spin frames must not rebuild the surrounding screen.');

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('controller highlight updates the Semantics label at runtime',
        (tester) async {
      final controller = GlobeController();
      addTearDown(controller.dispose);

      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RealisticGlobe(controller: controller, size: 200),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      // Idle: generic label.
      expect(find.bySemanticsLabel('Interactive globe'), findsOneWidget);

      // Focus a real city; label must reflect it after a frame.
      controller.highlightCity(GlobeLocation(
        label: 'Sulaymaniyah',
        latitude: 35.5556,
        longitude: 45.4329,
      ));
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.bySemanticsLabel('Globe focused on Sulaymaniyah'),
          findsOneWidget);

      handle.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('dev perf overlay mounts and updates without exceptions',
        (tester) async {
      final controller = GlobeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RealisticGlobe(
                controller: controller,
                size: 200,
                debugShowPerfOverlay: true,
              ),
            ),
          ),
        ),
      );

      // Pump > 0.5s so the overlay publishes at least one sample.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(tester.takeException(), isNull);
      // The overlay text starts with 'FPS '.
      expect(find.textContaining('FPS '), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
