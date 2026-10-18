import '../utils/calendar_date.dart';
import 'punch_log.dart';
import 'punch_record.dart';

/// Counts, settings and their audit log are persisted in a single snapshot.
class PunchData {
  final List<PunchRecord> records;
  final List<PunchLog> logs;
  final String punchName;
  final int idealIntervalDays;

  PunchData({
    List<PunchRecord> records = const [],
    List<PunchLog> logs = const [],
    this.punchName = '每日打卡',
    this.idealIntervalDays = 1,
  }) : records = List.unmodifiable(_mergeRecords(records)),
       logs = List.unmodifiable(logs);

  PunchData copyWith({
    List<PunchRecord>? records,
    List<PunchLog>? logs,
    String? punchName,
    int? idealIntervalDays,
  }) => PunchData(
    records: records ?? this.records,
    logs: logs ?? this.logs,
    punchName: punchName ?? this.punchName,
    idealIntervalDays: idealIntervalDays ?? this.idealIntervalDays,
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'punchName': punchName,
    'idealIntervalDays': idealIntervalDays,
    'records': records.map((record) => record.toJson()).toList(),
    'logs': logs.map((log) => log.toJson()).toList(),
  };

  factory PunchData.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('不支持的数据版本');
    }
    final name = json['punchName'] as String;
    final interval = json['idealIntervalDays'] as int;
    if (name.trim().isEmpty || interval < 1 || interval > 365) {
      throw const FormatException('设置数据无效');
    }
    return PunchData(
      punchName: name,
      idealIntervalDays: interval,
      records: (json['records'] as List<dynamic>)
          .map((item) => PunchRecord.fromJson(item as Map<String, dynamic>))
          .toList(),
      logs: (json['logs'] as List<dynamic>)
          .map((item) => PunchLog.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  static List<PunchRecord> _mergeRecords(List<PunchRecord> records) {
    final counts = <DateTime, int>{};
    for (final record in records) {
      final date = calendarDate(record.date);
      counts[date] = (counts[date] ?? 0) + record.count;
    }
    return counts.entries
        .where((entry) => entry.value > 0)
        .map((entry) => PunchRecord(date: entry.key, count: entry.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}
