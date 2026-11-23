import 'package:flutter_test/flutter_test.dart';
import 'package:texo/core/live/device_intent.dart';

void main() {
  test('flashlight on', () {
    expect(parseDeviceIntent('فلاش هەڵکە')?.action, 'flashlight_on');
  });

  test('flashlight off is not on', () {
    expect(parseDeviceIntent('فلاش بکوژێنەوە')?.action, 'flashlight_off');
  });

  test('song takes the rest as argument', () {
    final r = parseDeviceIntent('گۆرانی بەرزان جەعفەر هەڵکە');
    expect(r?.action, 'song');
    expect(r?.argument, 'بەرزان جەعفەر هەڵکە');
  });

  test('unknown returns null', () {
    expect(parseDeviceIntent('هیچ'), isNull);
  });
}
