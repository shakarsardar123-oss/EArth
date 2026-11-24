import 'package:flutter_test/flutter_test.dart';
import 'package:texo/core/phone_agent/phone_control_processor.dart';

void main() {
  final p = PhoneControlProcessor(providerGetter: () => throw UnimplementedError());

  test('flashlight phrase is recognised by the fast path', () async {
    final r = await p.tryFastForTest('فلاش هەڵکە');
    expect(r, isNotNull);
  });
}
