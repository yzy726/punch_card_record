class PunchLog {
  final String id;
  final DateTime timestamp;
  final String action; // e.g., "Punch +1", "Punch -1", "Set Name"
  final String details;
  bool isDeleted; // Soft delete for UI

  PunchLog({
    required this.id,
    required this.timestamp,
    required this.action,
    required this.details,
    this.isDeleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'action': action,
      'details': details,
      'isDeleted': isDeleted,
    };
  }

  factory PunchLog.fromJson(Map<String, dynamic> json) {
    return PunchLog(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp']),
      action: json['action'] as String,
      details: json['details'] as String,
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }
}