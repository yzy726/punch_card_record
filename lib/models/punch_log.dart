class PunchLog {
  final String id;
  final DateTime timestamp;
  final String action;
  final String details;
  final bool isDeleted;

  const PunchLog({
    required this.id,
    required this.timestamp,
    required this.action,
    required this.details,
    this.isDeleted = false,
  });

  PunchLog copyWith({bool? isDeleted}) => PunchLog(
        id: id,
        timestamp: timestamp,
        action: action,
        details: details,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'action': action,
        'details': details,
        'isDeleted': isDeleted,
      };

  factory PunchLog.fromJson(Map<String, dynamic> json) => PunchLog(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
        action: json['action'] as String,
        details: json['details'] as String,
        isDeleted: json['isDeleted'] as bool? ?? false,
      );
}