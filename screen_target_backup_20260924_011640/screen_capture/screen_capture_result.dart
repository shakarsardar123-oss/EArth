/// Result models for the AURA screen-capture subsystem.
///
/// [CapturedFrame] holds raw pixel data and metadata from a single
/// frame read. [ScreenCaptureConfig] specifies capture parameters
/// for starting a session.
library;

import 'package:meta/meta.dart' show immutable;

/// Configuration for a screen-capture session.
@immutable
class ScreenCaptureConfig {
  const ScreenCaptureConfig({
    this.width = 720,
    this.height = 1280,
    this.density = 160,
    this.maxFramesPerSecond = 5,
  this.pixelFormat = PixelFormat.rgba,
  this.rotation = 0,
  });

  /// Width of the VirtualDisplay surface.
  final int width;

  /// Height of the VirtualDisplay surface.
  final int height;

  /// Display density (dpi).
  final int density;

  /// Maximum frames per second to deliver (throttle cap).
  final int maxFramesPerSecond;

  /// Pixel format of captured frames.
  final PixelFormat pixelFormat;

  /// Initial rotation (0, 90, 180, 270).
  final int rotation;

  /// Minimum interval between frames in milliseconds.
  int get minFrameIntervalMs =>
      maxFramesPerSecond > 0 ? (1000 / maxFramesPerSecond).round() : 200;

  /// Serialise to a map for the platform channel.
  Map<String, dynamic> toMap() => {
        'width': width,
        'height': height,
        'density': density,
        'maxFramesPerSecond': maxFramesPerSecond,
        'pixelFormat': pixelFormat.name,
        'rotation': rotation,
      };

  @override
  String toString() =>
      'ScreenCaptureConfig(${width}x$height, density: $density, '
      'fps: $maxFramesPerSecond, format: $pixelFormat)';
}

/// Pixel format of captured frames.
enum PixelFormat {
  /// RGBA_8888 — 4 bytes per pixel.
  rgba,

  /// BGRA_8888 — 4 bytes per pixel (common on Android ImageReader).
  bgra,

  /// RGB_565 — 2 bytes per pixel.
  rgb565;

  /// Bytes per pixel for this format.
  int get bytesPerPixel => switch (this) {
        PixelFormat.rgba => 4,
        PixelFormat.bgra => 4,
        PixelFormat.rgb565 => 2,
      };
}

/// A single captured frame with raw pixel data and metadata.
///
/// Frames are delivered from the platform side through an EventChannel
/// stream. Each frame carries its pixel buffer plus dimensions and
/// timing information.
@immutable
class CapturedFrame {
  const CapturedFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.timestamp,
    this.rotation = 0,
    this.pixelFormat = PixelFormat.rgba,
  });

  /// Raw pixel bytes.
  final Uint8ListSafe bytes;

  /// Frame width in pixels.
  final int width;

  /// Frame height in pixels.
  final int height;

  /// Epoch-millis timestamp when the frame was captured.
  final int timestamp;

  /// Rotation of the frame (0, 90, 180, 270).
  final int rotation;

  /// Pixel format of the byte buffer.
  final PixelFormat pixelFormat;

  /// Expected byte length for this frame's dimensions and format.
  int get expectedByteLength =>
      width * height * pixelFormat.bytesPerPixel;

  @override
  String toString() =>
      'CapturedFrame(${width}x$height, ${bytes.length} bytes, '
      'rotation: $rotation, ts: $timestamp)';
}

/// A simple wrapper around a list of bytes that is immutable from the
/// outside. This avoids exposing `Uint8List` directly which requires
/// `dart:typed_data` and makes testing easier.
class Uint8ListSafe {
  const Uint8ListSafe(this._data);

  final List<int> _data;

  /// Length in bytes.
  int get length => _data.length;

  /// Element at [index].
  int operator [](int index) => _data[index];

  /// Returns a copy as a regular List<int>.
  List<int> toList() => List<int>.from(_data);

  @override
  String toString() => 'Uint8ListSafe(${_data.length} bytes)';
}
