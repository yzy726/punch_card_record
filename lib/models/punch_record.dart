class PunchRecord {
  final DateTime date;
  final int count;

  PunchRecord({required this.date, required this.count});

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'count': count,
    };
  }

  // Create from JSON
  factory PunchRecord.fromJson(Map<String, dynamic> json) {
    return PunchRecord(
      date: DateTime.parse(json['date']),
      count: json['count'] as int,
    );
  }
}