import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/screen_capture/screen_capture_result.dart';

void main() {
  group('PixelFormat', () {
    test('rgba has 4 bytes per pixel', () {
      expect(PixelFormat.rgba.bytesPerPixel, 4);
    });

    test('bgra has 4 bytes per pixel', () {
      expect(PixelFormat.bgra.bytesPerPixel, 4);
    });

    test('rgb565 has 2 bytes per pixel', () {
      expect(PixelFormat.rgb565.bytesPerPixel, 2);
    });

    test('all three formats exist', () {
      expect(PixelFormat.values, hasLength(3));
    });

    test('name property matches enum name', () {
      expect(PixelFormat.rgba.name, 'rgba');
      expect(PixelFormat.bgra.name, 'bgra');
      expect(PixelFormat.rgb565.name, 'rgb565');
    });
  });

  group('ScreenCaptureConfig', () {
    test('default constructor has sensible defaults', () {
      const config = ScreenCaptureConfig();
      expect(config.width, 720);
      expect(config.height, 1280);
      expect(config.density, 160);
      expect(config.maxFramesPerSecond, 5);
      expect(config.pixelFormat, PixelFormat.rgba);
      expect(config.rotation, 0);
    });

    test('minFrameIntervalMs computes correctly', () {
      const fps5 = ScreenCaptureConfig(maxFramesPerSecond: 5);
      expect(fps5.minFrameIntervalMs, 200);

      const fps10 = ScreenCaptureConfig(maxFramesPerSecond: 10);
      expect(fps10.minFrameIntervalMs, 100);

      const fps1 = ScreenCaptureConfig(maxFramesPerSecond: 1);
      expect(fps1.minFrameIntervalMs, 1000);
    });

    test('minFrameIntervalMs handles zero fps gracefully', () {
      const config = ScreenCaptureConfig(maxFramesPerSecond: 0);
      expect(config.minFrameIntervalMs, 200);
    });

    test('toMap contains all fields', () {
      const config = ScreenCaptureConfig(
        width: 1080,
        height: 1920,
        density: 320,
        maxFramesPerSecond: 10,
        pixelFormat: PixelFormat.bgra,
        rotation: 90,
      );
      final map = config.toMap();

      expect(map['width'], 1080);
      expect(map['height'], 1920);
      expect(map['density'], 320);
      expect(map['maxFramesPerSecond'], 10);
      expect(map['pixelFormat'], 'bgra');
      expect(map['rotation'], 90);
    });

    test('toString includes dimensions and format', () {
      const config = ScreenCaptureConfig();
      final str = config.toString();
      expect(str, contains('720'));
      expect(str, contains('1280'));
      expect(str, contains('rgba'));
    });

    test('custom values are preserved', () {
      const config = ScreenCaptureConfig(
        width: 1080,
        height: 2400,
        density: 440,
        maxFramesPerSecond: 2,
        pixelFormat: PixelFormat.rgb565,
        rotation: 270,
      );
      expect(config.width, 1080);
      expect(config.height, 2400);
      expect(config.density, 440);
      expect(config.maxFramesPerSecond, 2);
      expect(config.pixelFormat, PixelFormat.rgb565);
      expect(config.rotation, 270);
    });
  });

  group('Uint8ListSafe', () {
    test('holds bytes and reports length', () {
      const data = Uint8ListSafe([1, 2, 3, 4, 5]);
      expect(data.length, 5);
    });

    test('index access returns correct byte', () {
      const data = Uint8ListSafe([10, 20, 30]);
      expect(data[0], 10);
      expect(data[1], 20);
      expect(data[2], 30);
    });

    test('toList returns a copy', () {
      const data = Uint8ListSafe([1, 2, 3]);
      final list = data.toList();
      expect(list, [1, 2, 3]);
      // Mutating the copy must not affect the original.
      list[0] = 99;
      expect(data[0], 1);
    });

    test('toString includes byte count', () {
      const data = Uint8ListSafe([1, 2]);
      expect(data.toString(), contains('2'));
      expect(data.toString(), contains('bytes'));
    });
  });

  group('CapturedFrame', () {
    test('constructor stores all fields', () {
      const frame = CapturedFrame(
        bytes: Uint8ListSafe([0xFF, 0x00, 0xFF, 0x00]),
        width: 1,
        height: 1,
        timestamp: 1700000000000,
        rotation: 90,
        pixelFormat: PixelFormat.rgba,
      );

      expect(frame.width, 1);
      expect(frame.height, 1);
      expect(frame.timestamp, 1700000000000);
      expect(frame.rotation, 90);
      expect(frame.pixelFormat, PixelFormat.rgba);
      expect(frame.bytes.length, 4);
    });

    test('expectedByteLength calculates correctly for rgba', () {
      const frame = CapturedFrame(
        bytes: Uint8ListSafe([]),
        width: 720,
        height: 1280,
        timestamp: 0,
        pixelFormat: PixelFormat.rgba,
      );
      // 720 * 1280 * 4 = 3,686,400
      expect(frame.expectedByteLength, 720 * 1280 * 4);
    });

    test('expectedByteLength calculates correctly for rgb565', () {
      const frame = CapturedFrame(
        bytes: Uint8ListSafe([]),
        width: 100,
        height: 100,
        timestamp: 0,
        pixelFormat: PixelFormat.rgb565,
      );
      expect(frame.expectedByteLength, 100 * 100 * 2);
    });

    test('default rotation is 0 and default format is rgba', () {
      const frame = CapturedFrame(
        bytes: Uint8ListSafe([]),
        width: 10,
        height: 10,
        timestamp: 0,
      );
      expect(frame.rotation, 0);
      expect(frame.pixelFormat, PixelFormat.rgba);
    });

    test('toString includes dimensions and byte count', () {
      const frame = CapturedFrame(
        bytes: Uint8ListSafe([1, 2, 3, 4]),
        width: 2,
        height: 2,
        timestamp: 1000,
      );
      final str = frame.toString();
      expect(str, contains('2x2'));
      expect(str, contains('4 bytes'));
      expect(str, contains('1000'));
    });
  });
}
