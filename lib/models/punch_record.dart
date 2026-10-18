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

  Map<String, dynamic> toJson() => {
        'date': dateLabel(date),
        'count': count,
      };

  factory PunchRecord.fromJson(Map<String, dynamic> json) => PunchRecord(
        date: DateTime.parse(json['date'] as String),
        count: json['count'] as int,
      );
}
