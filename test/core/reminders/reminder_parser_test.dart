import 'package:flutter_test/flutter_test.dart';
import 'package:texo/core/reminders/reminder_parser.dart';

void main() {
  final now = DateTime(2026, 11, 24, 10, 0);

  test('relative minutes', () {
    expect(parseReminderTime('دوای ١٠ خولەک', now), now.add(const Duration(minutes: 10)));
  });

  test('evening 5 is 17:00', () {
    expect(parseReminderTime('٥ی ئێوارە', now), DateTime(2026, 11, 24, 17, 0));
  });

  test('morning 9 is 09:00 next day when already past', () {
    expect(parseReminderTime('٩ی بەیانی', now), DateTime(2026, 11, 25, 9, 0));
  });

  test('midnight 12 at night is 00:00 next day', () {
    expect(parseReminderTime('١٢ی شەو', now), DateTime(2026, 11, 25, 0, 0));
  });

  test('gibberish returns null', () {
    expect(parseReminderTime('هیچ', now), isNull);
  });
}
