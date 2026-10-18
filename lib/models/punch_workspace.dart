import 'punch_data.dart';

class PunchHabit {
  const PunchHabit({required this.id, required this.data});

  final String id;
  final PunchData data;

  Map<String, dynamic> toJson() => {'id': id, 'data': data.toJson()};

  factory PunchHabit.fromJson(Map<String, dynamic> json) => PunchHabit(
    id: json['id'] as String,
    data: PunchData.fromJson(json['data'] as Map<String, dynamic>),
  );
}

/// Each habit owns its settings, records and logs. Stable IDs allow backups
/// from different devices to merge even after a habit has been renamed.
class PunchWorkspace {
  PunchWorkspace({required List<PunchHabit> habits, required this.activeHabitId})
    : habits = List.unmodifiable(habits) {
    if (habits.isEmpty ||
        habits.any((habit) => habit.id.isEmpty) ||
        habits.map((habit) => habit.id).toSet().length != habits.length ||
        !habits.any((habit) => habit.id == activeHabitId)) {
      throw const FormatException('打卡项目数据无效');
    }
  }

  factory PunchWorkspace.single(PunchData data) => PunchWorkspace(
    habits: [PunchHabit(id: 'legacy', data: data)],
    activeHabitId: 'legacy',
  );

  final List<PunchHabit> habits;
  final String activeHabitId;

  PunchHabit get active => habits.firstWhere((habit) => habit.id == activeHabitId);

  PunchWorkspace copyWith({List<PunchHabit>? habits, String? activeHabitId}) =>
      PunchWorkspace(
        habits: habits ?? this.habits,
        activeHabitId: activeHabitId ?? this.activeHabitId,
      );

  PunchWorkspace withData(String id, PunchData data) => copyWith(
    habits: habits.map((habit) => habit.id == id ? PunchHabit(id: id, data: data) : habit).toList(),
  );

  Map<String, dynamic> toJson() => {
    'version': 2,
    'activeHabitId': activeHabitId,
    'habits': habits.map((habit) => habit.toJson()).toList(),
  };

  factory PunchWorkspace.fromJson(Map<String, dynamic> json) {
    if (json['version'] == 1) {
      return PunchWorkspace.single(PunchData.fromJson(json));
    }
    if (json['version'] != 2) throw const FormatException('不支持的数据版本');
    return PunchWorkspace(
      activeHabitId: json['activeHabitId'] as String,
      habits: (json['habits'] as List<dynamic>)
          .map((item) => PunchHabit.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
