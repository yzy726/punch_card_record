import '../utils/calendar_date.dart';

class PunchRecord {
  final DateTime date;
  final int count;

  PunchRecord({required DateTime date, required this.count})
    : date = calendarDate(date) {
    if (count < 0 || count > 2147483647) {
      throw const FormatException('打卡次数超出有效范围');
    }
  }

  Map<String, dynamic> toJson() => {'date': dateLabel(date), 'count': count};

  factory PunchRecord.fromJson(Map<String, dynamic> json) {
    final value = json['date'] as String;
    final parts = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:T.*)?$',
    ).firstMatch(value);
    final date = DateTime.tryParse(value);
    if (parts == null ||
        date == null ||
        date.year != int.parse(parts[1]!) ||
        date.month != int.parse(parts[2]!) ||
        date.day != int.parse(parts[3]!)) {
      throw const FormatException('打卡日期无效');
    }
    return PunchRecord(date: date, count: json['count'] as int);
  }
}
