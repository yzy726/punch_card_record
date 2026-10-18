import 'package:flutter_test/flutter_test.dart';
import 'package:punch_card_record/models/punch_record.dart';
import 'package:punch_card_record/utils/calendar_date.dart';

void main() {
  test('UTC calendar dates preserve the selected day in every timezone', () {
    final utc = DateTime.utc(2026, 10, 18, 23, 59);
    expect(calendarDate(utc), DateTime(2026, 10, 18));
    expect(sameCalendarDay(utc, DateTime(2026, 10, 18, 0, 1)), isTrue);
  });

  test('calendar day differences survive daylight saving transitions', () {
    expect(calendarDaysBetween(DateTime(2026, 3, 8), DateTime(2026, 3, 9)), 1);
    expect(
      calendarDaysBetween(DateTime(2026, 11, 1), DateTime(2026, 11, 2)),
      1,
    );
    expect(
      calendarDaysBetween(DateTime(2026, 12, 31), DateTime(2027, 1, 1)),
      1,
    );
  });

  test('old UTC records migrate to a date-only representation', () {
    final record = PunchRecord.fromJson({
      'date': '2026-10-18T00:00:00.000Z',
      'count': 2,
    });
    expect(record.date, DateTime(2026, 10, 18));
    expect(record.toJson(), {'date': '2026-10-18', 'count': 2});
  });

  test('invalid backup dates cannot silently roll into another month', () {
    expect(
      () => PunchRecord.fromJson({'date': '2026-02-30', 'count': 1}),
      throwsFormatException,
    );
    expect(
      () => PunchRecord.fromJson({'date': '2026-10-18', 'count': -1}),
      throwsFormatException,
    );
  });
}
