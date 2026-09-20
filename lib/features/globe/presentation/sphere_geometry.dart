/// sphere_geometry.dart
/// AURA — Static UV-sphere mesh + per-frame CPU transform for the textured
/// 3D Earth renderer.
///
/// DESIGN / PERFORMANCE CONTRACT:
///   • The unit-sphere vertex grid (positions + normalized UVs + triangle
///     indices) is generated EXACTLY ONCE and reused for the life of the app.
///   • Per frame we only apply a 3x3 rotation (two angles → no per-vertex
///     trig) and an orthographic projection, writing into pre-allocated,
///     reused typed-array buffers — no per-frame mesh or buffer allocation.
///   • The mesh is drawn with a single [ui.Vertices]/`drawVertices` call per
///     texture layer, so the GPU rasterizes the textured triangles; the CPU
///     only transforms a few thousand vertices.
///   • Back-facing triangles (far hemisphere) are culled per frame by
///     centroid depth, so no depth buffer is required for a convex sphere.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// A reusable equirectangular UV sphere.
class SphereMesh {
  SphereMesh._({
    required this.stacks,
    required this.slices,
    required this.vertexCount,
    required this.baseX,
    required this.baseY,
    required this.baseZ,
    required this.uv,
    required this.indices,
  })  : _screen = Float32List(vertexCount * 2),
        _depth = Float32List(vertexCount),
        _dayColors = Int32List(vertexCount),
        _nightColors = Int32List(vertexCount),
        _indexScratch = Uint16List(indices.length);

  /// Build a sphere with [stacks] latitude bands and [slices] longitude bands.
  factory SphereMesh.generate({int stacks = 40, int slices = 80}) {
    final int cols = slices + 1; // duplicate seam column for clean UVs
    final int rows = stacks + 1;
    final int nv = rows * cols;
    final baseX = Float32List(nv);
    final baseY = Float32List(nv);
    final baseZ = Float32List(nv);
    final uv = Float32List(nv * 2);

    int vi = 0;
    for (int r = 0; r < rows; r++) {
      // lat from +90 (north/top) down to -90 (south/bottom)
      final double vFrac = r / stacks; // 0..1
      final double lat = (math.pi / 2) - vFrac * math.pi;
      final double cosLat = math.cos(lat);
      final double sinLat = math.sin(lat);
      for (int c = 0; c < cols; c++) {
        final double uFrac = c / slices; // 0..1
        final double lon = -math.pi + uFrac * (2 * math.pi);
        // (lat=0,lon=0) faces the camera at +Z.
        baseX[vi] = cosLat * math.sin(lon);
        baseY[vi] = sinLat;
        baseZ[vi] = cosLat * math.cos(lon);
        uv[vi * 2] = uFrac; // u: lon -180..180 → 0..1
        uv[vi * 2 + 1] = vFrac; // v: lat +90..-90 → 0..1
        vi++;
      }
    }

    // Triangle indices (two per grid cell).
    final indices = Uint16List(stacks * slices * 6);
    int ii = 0;
    for (int r = 0; r < stacks; r++) {
      for (int c = 0; c < slices; c++) {
        final int i0 = r * cols + c;
        final int i1 = i0 + 1;
        final int i2 = i0 + cols;
        final int i3 = i2 + 1;
        indices[ii++] = i0;
        indices[ii++] = i2;
        indices[ii++] = i1;
        indices[ii++] = i1;
        indices[ii++] = i2;
        indices[ii++] = i3;
      }
    }

    return SphereMesh._(
      stacks: stacks,
      slices: slices,
      vertexCount: nv,
      baseX: baseX,
      baseY: baseY,
      baseZ: baseZ,
      uv: uv,
      indices: indices,
    );
  }

  final int stacks;
  final int slices;
  final int vertexCount;

  // Baked unit-sphere positions (never mutated).
  final Float32List baseX;
  final Float32List baseY;
  final Float32List baseZ;

  /// Normalized UVs (0..1) per vertex, length vertexCount*2.
  final Float32List uv;

  /// Full-sphere triangle indices (never mutated).
  final Uint16List indices;

  // ── Reused per-frame scratch buffers (no per-frame allocation) ──
  final Float32List _screen; // projected x,y per vertex
  final Float32List _depth; // rotated z (>=0 == front hemisphere)
  final Int32List _dayColors; // lambert-shaded white (BlendMode.modulate)
  final Int32List _nightColors; // city-light intensity (BlendMode.plus)
  final Uint16List _indexScratch; // visible (front-facing) triangle indices
  int _visibleIndexCount = 0;

  // Per-texture pixel-space UV caches (drawVertices texture coords must be in
  // the image's pixel space). Built once per (w,h) and reused every frame.
  final Map<int, Float32List> _texCoordCache = <int, Float32List>{};

  Float32List _texCoordsForImage(ui.Image img) {
    final int key = img.width * 100000 + img.height;
    return _texCoordCache.putIfAbsent(key, () {
      final Float32List t = Float32List(vertexCount * 2);
      final double w = img.width.toDouble();
      final double h = img.height.toDouble();
      for (int i = 0; i < vertexCount; i++) {
        t[i * 2] = uv[i * 2] * w;
        t[i * 2 + 1] = uv[i * 2 + 1] * h;
      }
      return t;
    });
  }

  /// Result of one frame's transform — lightweight handle over reused buffers.
  SphereFrame transform({
    required double lon0Deg,
    required double lat0Deg,
    required double radius,
    required double cx,
    required double cy,
    required double lightX,
    required double lightY,
    required double lightZ,
    double ambient = 0.16,
  }) {
    const double deg2rad = math.pi / 180.0;
    // Rotation to bring (lat0,lon0) to face the camera:
    //   Ry(a = -lon0):  x' = x*ca + z*sa ; z' = -x*sa + z*ca
    //   Rx(b =  lat0):  y'' = y*cb - z'*sb ; z'' = y*sb + z'*cb
    final double lon = lon0Deg * deg2rad;
    final double lat = lat0Deg * deg2rad;
    final double ca = math.cos(lon);
    final double sa = math.sin(lon); // sin(-lon0) folded into formulas below
    final double cb = math.cos(lat);
    final double sb = math.sin(lat);

    // Normalize light direction once.
    final double ll =
        math.sqrt(lightX * lightX + lightY * lightY + lightZ * lightZ);
    final double lx = lightX / ll;
    final double ly = lightY / ll;
    final double lz = lightZ / ll;

    for (int i = 0; i < vertexCount; i++) {
      final double x = baseX[i];
      final double y = baseY[i];
      final double z = baseZ[i];
      // Ry(-lon0): a=-lon0 → cos a = ca, sin a = -sa.
      final double x1 = x * ca - z * sa;
      final double z1 = x * sa + z * ca;
      final double y1 = y;
      // Rx(lat0):
      final double y2 = y1 * cb - z1 * sb;
      final double z2 = y1 * sb + z1 * cb;
      final double x2 = x1;

      _screen[i * 2] = cx + x2 * radius;
      _screen[i * 2 + 1] = cy - y2 * radius;
      _depth[i] = z2;

      // Lambert lighting: rotated position == outward normal on a unit sphere.
      double d = x2 * lx + y2 * ly + z2 * lz;
      // Day shade (smooth terminator).
      double day = d <= 0 ? 0.0 : (d >= 1 ? 1.0 : d);
      day = day * day * (3 - 2 * day); // smoothstep
      final double mult = ambient + (1 - ambient) * day;
      final int m = (mult.clamp(0.0, 1.0) * 255).round();
      _dayColors[i] = 0xFF000000 | (m << 16) | (m << 8) | m;

      // Night city-lights intensity on the dark side.
      double night = (-d) - 0.02;
      night = night <= 0 ? 0.0 : (night >= 1 ? 1.0 : night);
      night = night * night * (3 - 2 * night);
      final int n = (night * 255).round();
      _nightColors[i] = 0xFF000000 | (n << 16) | (n << 8) | n;
    }

    // Cull back-facing triangles by centroid depth; build visible index list.
    int out = 0;
    final idx = indices;
    final scratch = _indexScratch;
    for (int t = 0; t < idx.length; t += 3) {
      final int a = idx[t];
      final int b = idx[t + 1];
      final int c = idx[t + 2];
      // Front-facing if the triangle centroid is on the near hemisphere.
      if ((_depth[a] + _depth[b] + _depth[c]) >= 0) {
        scratch[out++] = a;
        scratch[out++] = b;
        scratch[out++] = c;
      }
    }
    _visibleIndexCount = out;

    return SphereFrame._(this);
  }

  Uint16List get _visibleIndices =>
      Uint16List.sublistView(_indexScratch, 0, _visibleIndexCount);

  /// Build the [ui.Vertices] for a texture layer using the given per-vertex
  /// colors. Reuses the cached screen positions, pixel-space texcoords and
  /// visible-triangle indices for [image].
  ui.Vertices buildVertices(ui.Image image, Int32List colors) {
    return ui.Vertices.raw(
      ui.VertexMode.triangles,
      _screen,
      textureCoordinates: _texCoordsForImage(image),
      colors: colors,
      indices: _visibleIndices,
    );
  }

  Int32List get dayColors => _dayColors;
  Int32List get nightColors => _nightColors;
  Float32List get screen => _screen;
  int get visibleIndexCount => _visibleIndexCount;
}

/// Immutable per-frame handle (all data lives in the reused mesh buffers).
class SphereFrame {
  const SphereFrame._(this.mesh);
  final SphereMesh mesh;
}
