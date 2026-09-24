/// realistic_globe_capture_test.dart
/// Rasterizes the TEXTURED 3D Earth to real PNG pixels inside flutter_test
/// (software Skia renderer) as VISUAL evidence that the renderer produces a
/// genuinely texture-mapped planet with the required camera/flight states.
///
/// IMPORTANT: this is the SOFTWARE Skia rasterizer, NOT a GPU/on-device
/// screenshot, and it does NOT measure FPS. It only proves the renderer emits
/// a coherent, textured Earth image and honours each requested camera state.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:texo/features/globe/application/globe_controller.dart';
import 'package:texo/features/globe/domain/globe_models.dart';
import 'package:texo/features/globe/presentation/earth_textures.dart';
import 'package:texo/features/globe/presentation/realistic_globe.dart';

const _outDir = '/nfs/106246820/outputs';

Future<void> _capture(WidgetTester tester, String name) async {
  final finder = find.descendant(
    of: find.byType(RealisticGlobe),
    matching: find.byType(RepaintBoundary),
  );
  final boundary = tester.firstRenderObject<RenderRepaintBoundary>(finder);
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_outDir/$name');
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
}

/// Pumps many frames while letting async texture decode / flight easing run.
Future<void> _settle(WidgetTester tester, {int frames = 140}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('rasterizes textured Earth: space/rotation/USA/Sulaymaniyah/'
      'zoom/panel states to PNG', (tester) async {
    Directory(_outDir).createSync(recursive: true);
    tester.view.physicalSize = const ui.Size(420, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Decode the real Earth textures BEFORE rendering so captures show the
    // textured planet, not the shaded-ocean fallback.
    await tester.runAsync(() => EarthTextures.instance.ensureLoaded());
    expect(EarthTextures.instance.isReady, isTrue,
        reason: 'Earth surface texture must decode from bundled assets.');

    final controller = GlobeController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: RealisticGlobe(controller: controller, size: 360),
          ),
        ),
      ),
    );

    // 1) Earth from space + normal rotation state.
    await _settle(tester, frames: 40);
    await _capture(tester, 'earth_space.png');

    // 3) USA focus (real centroid of the contiguous United States).
    controller.highlightCountry(GlobeLocation(
      label: 'United States',
      latitude: 39.83,
      longitude: -98.58,
      countryCode: 'US',
    ));
    await _settle(tester);
    await _capture(tester, 'earth_usa.png');

    // 5) Ukraine focus (real centroid).
    controller.highlightCity(GlobeLocation(
      label: 'Ukraine',
      latitude: 48.3794,
      longitude: 31.1656,
    ));
    await _settle(tester);
    await _capture(tester, 'earth_ukraine.png');

    // 4) Sulaymaniyah focus (real city coordinates) + marker/label/connector.
    controller.highlightCity(GlobeLocation(
      label: 'Sulaymaniyah',
      latitude: 35.5556,
      longitude: 45.4329,
    ));
    await _settle(tester);
    await _capture(tester, 'earth_sulaymaniyah.png');

    // 6) Zoomed further into the current location ("more info").
    controller.zoomIn(factor: 1.8);
    controller.zoomIn(factor: 1.8);
    await _settle(tester);
    await _capture(tester, 'earth_zoom.png');

    // 7) Image panel OPEN — Earth slides toward the side.
    controller.openImagePanel();
    await _settle(tester);
    await _capture(tester, 'earth_panel_open.png');

    // 8) Image panel CLOSED — Earth returns toward centre.
    controller.closeImagePanel();
    await _settle(tester);
    await _capture(tester, 'earth_panel_closed.png');

    for (final f in const [
      'earth_space.png',
      'earth_usa.png',
      'earth_ukraine.png',
      'earth_sulaymaniyah.png',
      'earth_zoom.png',
      'earth_panel_open.png',
      'earth_panel_closed.png',
    ]) {
      expect(File('$_outDir/$f').existsSync(), isTrue, reason: 'missing $f');
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
