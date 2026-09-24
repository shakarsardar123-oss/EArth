/// earth_renderer_test.dart
/// Focused tests for the textured 3D Earth renderer's building blocks:
/// the static [SphereMesh] (initialization, reuse, back-face culling,
/// projection) and the [EarthTextures] loader (decode-once + cache).
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:texo/features/globe/presentation/earth_textures.dart';
import 'package:texo/features/globe/presentation/sphere_geometry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SphereMesh (static geometry, created once)', () {
    test('generates the expected vertex + index counts', () {
      final mesh = SphereMesh.generate(stacks: 40, slices: 80);
      expect(mesh.vertexCount, (40 + 1) * (80 + 1)); // rows*cols
      expect(mesh.indices.length, 40 * 80 * 6); // 2 triangles per cell
      // UVs are normalized 0..1.
      for (var i = 0; i < mesh.uv.length; i++) {
        expect(mesh.uv[i], inInclusiveRange(0.0, 1.0));
      }
    });

    test('transform culls the back hemisphere and keeps the front', () {
      final mesh = SphereMesh.generate(stacks: 24, slices: 48);
      mesh.transform(
        lon0Deg: 0,
        lat0Deg: 0,
        radius: 100,
        cx: 200,
        cy: 200,
        lightX: -0.5,
        lightY: 0.38,
        lightZ: 0.78,
      );
      // Some triangles visible, but strictly fewer than the whole sphere
      // (the far hemisphere is culled), and always a whole number of tris.
      expect(mesh.visibleIndexCount, greaterThan(0));
      expect(mesh.visibleIndexCount, lessThan(mesh.indices.length));
      expect(mesh.visibleIndexCount % 3, 0);
      // Front hemisphere is ~half → visible indices in a sane band.
      expect(
        mesh.visibleIndexCount,
        inInclusiveRange(
          mesh.indices.length ~/ 4,
          (mesh.indices.length * 3) ~/ 4,
        ),
      );
    });

    test('projected screen coordinates are finite', () {
      final mesh = SphereMesh.generate(stacks: 16, slices: 32);
      mesh.transform(
        lon0Deg: 45,
        lat0Deg: 20,
        radius: 80,
        cx: 150,
        cy: 150,
        lightX: -0.5,
        lightY: 0.38,
        lightZ: 0.78,
      );
      final Float32List s = mesh.screen;
      for (var i = 0; i < s.length; i++) {
        expect(s[i].isFinite, isTrue);
      }
      // Day-shade colors are opaque ARGB.
      for (var i = 0; i < mesh.dayColors.length; i++) {
        expect((mesh.dayColors[i] >> 24) & 0xFF, 0xFF);
      }
    });

    test('rotating the center longitude changes which triangles are visible',
        () {
      final mesh = SphereMesh.generate(stacks: 24, slices: 48);
      mesh.transform(
          lon0Deg: 0,
          lat0Deg: 0,
          radius: 100,
          cx: 100,
          cy: 100,
          lightX: 0,
          lightY: 0,
          lightZ: 1,
      );
      final front = Float32List.fromList(mesh.screen);
      mesh.transform(
          lon0Deg: 120,
          lat0Deg: 0,
          radius: 100,
          cx: 100,
          cy: 100,
          lightX: 0,
          lightY: 0,
          lightZ: 1,
      );
      // At least some projected positions moved after rotation.
      var moved = 0;
      for (var i = 0; i < front.length; i++) {
        if ((front[i] - mesh.screen[i]).abs() > 0.5) moved++;
      }
      expect(moved, greaterThan(0));
    });
  });

  group('EarthTextures (decode once + cache)', () {
    testWidgets('loads the bundled NASA textures and caches them',
        (tester) async {
      final tex = EarthTextures.instance;
      tex.resetForTest();
      await tester.runAsync(() => tex.ensureLoaded());

      expect(tex.isReady, isTrue);
      expect(tex.surface, isNotNull);
      expect(tex.clouds, isNotNull);
      expect(tex.night, isNotNull);
      // Equirectangular (2:1) surface texture.
      expect(tex.surface!.width, tex.surface!.height * 2);

      // Second call is a no-op (same cached image identity).
      final before = identityHashCode(tex.surface);
      await tester.runAsync(() => tex.ensureLoaded());
      expect(identityHashCode(tex.surface), before);
    });
  });
}
