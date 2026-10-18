import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/punch_backup.dart';
import '../models/punch_data.dart';
import '../models/punch_log.dart';
import '../models/punch_record.dart';
import '../models/punch_workspace.dart';
import '../services/storage_service.dart';
import '../utils/calendar_date.dart';

class PunchProvider with ChangeNotifier {
  PunchProvider({StorageService? storageService, DateTime Function()? clock})
    : _storage = storageService ?? StorageService(),
      _clock = clock ?? DateTime.now {
    ready = _loadData();
  }

  final StorageService _storage;
  final DateTime Function() _clock;
  final Uuid _uuid = const Uuid();
  PunchWorkspace _workspace = PunchWorkspace.single(PunchData());
  PunchData get _data => _workspace.active.data;
  List<PunchHabit> get habits => _workspace.habits;
  String get activeHabitId => _workspace.activeHabitId;
  PunchWorkspace get workspace => _workspace;
  Future<void> _writeQueue = Future<void>.value();
  late Future<void> ready;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _disposed = false;
  String? _loadError;

  List<PunchRecord> get records => _data.records;
  List<PunchLog> get logs => _data.logs;
  String get punchName => _data.punchName;
  int get idealIntervalDays => _data.idealIntervalDays;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get loadError => _loadError;
  String? get recoveryMessage => _storage.recoveryMessage;
  DateTime get today => calendarDate(_clock());

  Future<void> _loadData() async {
    _isLoading = true;
    _loadError = null;
    _notify();
    try {
      _workspace = await _storage.load();
    } on Object {
      _loadError = '暂时无法读取本地数据。请重试，已有文件会保留。';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> retryLoad() {
    if (_isLoading) return ready;
    return ready = _loadData();
  }

  void _validateSettings(String name, int interval, {PunchData? except}) {
    if (name.isEmpty || name.runes.length > 30) throw ArgumentError('名称需要 1–30 个字符');
    if (interval < 1 || interval > 365) throw ArgumentError('间隔需要为 1–365 天');
    if (habits.any((habit) => !identical(habit.data, except) && habit.data.punchName.toLowerCase() == name.toLowerCase())) {
      throw ArgumentError('已存在同名打卡，请换一个名称');
    }
  }

  Future<void> updateSettings(String name, int interval) => _change((data) {
    final trimmed = name.trim();
    _validateSettings(trimmed, interval, except: data);
    if (trimmed == data.punchName && interval == data.idealIntervalDays) return data;
    return data.copyWith(
      punchName: trimmed,
      idealIntervalDays: interval,
      logs: [_log('设置更新', '名称：$trimmed · 理想间隔：$interval 天'), ...data.logs],
    );
  });

  Future<void> createHabit(String name, int interval) => _changeWorkspace((workspace) {
    final trimmed = name.trim();
    _validateSettings(trimmed, interval);
    final id = _uuid.v4();
    return workspace.copyWith(
      habits: [...workspace.habits, PunchHabit(id: id, data: PunchData(
        punchName: trimmed,
        idealIntervalDays: interval,
        logs: [_log('创建打卡', '名称：$trimmed · 理想间隔：$interval 天')],
      ))],
      activeHabitId: id,
    );
  });

  Future<void> selectHabit(String id) => _changeWorkspace((workspace) {
    if (!workspace.habits.any((habit) => habit.id == id)) throw ArgumentError('打卡项目不存在');
    return workspace.activeHabitId == id ? workspace : workspace.copyWith(activeHabitId: id);
  });

  Future<void> deleteHabit(String id) => _changeWorkspace((workspace) {
    if (!workspace.habits.any((habit) => habit.id == id)) return workspace;
    if (workspace.habits.length == 1) throw StateError('至少需要保留一个打卡项目');
    final remaining = workspace.habits.where((habit) => habit.id != id).toList();
    return workspace.copyWith(
      habits: remaining,
      activeHabitId: workspace.activeHabitId == id ? remaining.first.id : workspace.activeHabitId,
    );
  });

  bool isFutureDate(DateTime date) => calendarDate(date).isAfter(today);

  int getCountForDate(DateTime date) {
    for (final record in records) {
      if (sameCalendarDay(record.date, date)) return record.count;
    }
    return 0;
  }

  Future<void> updatePunch(DateTime date, int change) => _change((data) {
    final day = calendarDate(date);
    if (isFutureDate(day)) throw ArgumentError('不能提前打卡未来的日期');
    final oldCount = data.records.where((record) => sameCalendarDay(record.date, day)).fold<int>(0, (sum, record) => sum + record.count);
    final newCount = (oldCount + change).clamp(0, 2147483647).toInt();
    if (oldCount == newCount) return data;
    final updated = data.records
        .where((record) => !sameCalendarDay(record.date, day))
        .toList();
    if (newCount > 0) {
      updated.add(PunchRecord(date: day, count: newCount));
    }
    final delta = newCount - oldCount;
    return data.copyWith(
      records: updated,
      logs: [
        _log(
          delta > 0 ? '打卡 +$delta' : '打卡 $delta',
          '${dateLabel(day)} · 当前 $newCount 次',
        ),
        ...data.logs,
      ],
    );
  });

  Future<void> softDeleteLog(String id) => _setLogHidden(id, true);
  Future<void> restoreLog(String id) => _setLogHidden(id, false);

  Future<String> exportBackup() async {
    await ready;
    await _writeQueue;
    if (_loadError != null) throw StateError(_loadError!);
    return PunchBackup(workspace: _workspace, exportedAt: _clock()).encode();
  }

  Future<void> importBackup(PunchBackup backup, {required bool replace}) =>
      _changeWorkspace((workspace) {
        if (backup.workspace.habits.any((habit) => habit.data.records.any((record) => isFutureDate(record.date)))) {
          throw const FormatException('备份中包含未来日期，请检查两台设备的时间');
        }
        PunchWorkspace imported;
        if (replace) {
          imported = backup.workspace;
        } else {
          final merged = {for (final habit in workspace.habits) habit.id: habit};
          for (final habit in backup.workspace.habits) {
            final local = merged[habit.id];
            merged[habit.id] = local == null ? habit : PunchHabit(id: habit.id, data: _mergeData(local.data, habit.data));
          }
          imported = workspace.copyWith(habits: merged.values.toList());
        }
        return imported.withData(imported.activeHabitId, imported.active.data.copyWith(logs: [
          _log('数据导入', '${replace ? '覆盖' : '合并'}备份 · ${backup.workspace.habits.length} 个打卡项目'),
          ...imported.active.data.logs,
        ]));
      });

  PunchData _mergeData(PunchData local, PunchData remote) {
    final counts = {for (final record in local.records) record.date: record.count};
    for (final record in remote.records) {
      if (record.count > (counts[record.date] ?? 0)) counts[record.date] = record.count;
    }
    final logs = {for (final log in remote.logs) log.id: log};
    for (final log in local.logs) { logs[log.id] = log; }
    final sorted = logs.values.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return local.copyWith(
      records: counts.entries.map((entry) => PunchRecord(date: entry.key, count: entry.value)).toList(),
      logs: sorted,
    );
  }

  Future<void> _setLogHidden(String id, bool hidden) => _change((data) {
    if (!data.logs.any((log) => log.id == id && log.isDeleted != hidden)) {
      return data;
    }
    return data.copyWith(
      logs: data.logs
          .map((log) => log.id == id ? log.copyWith(isDeleted: hidden) : log)
          .toList(),
    );
  });

  int monthTotal(DateTime month) => records
      .where(
        (record) =>
            record.date.year == month.year && record.date.month == month.month,
      )
      .fold(0, (sum, record) => sum + record.count);

  int monthActiveDays(DateTime month) => records
      .where(
        (record) =>
            record.date.year == month.year && record.date.month == month.month,
      )
      .length;

  int get currentStreak {
    var day = today;
    if (getCountForDate(day) == 0) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    var streak = 0;
    while (getCountForDate(day) > 0) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }

  DateTime? getLastPunchDate() {
    final pastRecords = records.where((record) => !isFutureDate(record.date));
    if (pastRecords.isEmpty) return null;
    return pastRecords.last.date;
  }

  DateTime? getNextIdealDate() {
    final last = getLastPunchDate();
    if (last == null) return null;
    return DateTime(last.year, last.month, last.day + idealIntervalDays);
  }

  PunchLog _log(String action, String details) => PunchLog(
    id: _uuid.v4(),
    timestamp: _clock(),
    action: action,
    details: details,
  );

  Future<void> _change(PunchData Function(PunchData) transform) {
    final requestedId = _isLoading ? null : activeHabitId;
    return _changeWorkspace((workspace) {
      final id = requestedId ?? workspace.activeHabitId;
      final habit = workspace.habits.firstWhere((habit) => habit.id == id);
      final next = transform(habit.data);
      return identical(next, habit.data) ? workspace : workspace.withData(id, next);
    });
  }

  Future<void> _changeWorkspace(PunchWorkspace Function(PunchWorkspace) transform) {
    // Serialize writes and publish a state only after it reaches disk.
    final operation = _writeQueue.then((_) async {
      await ready;
      if (_loadError != null) throw StateError(_loadError!);
      final next = transform(_workspace);
      if (identical(next, _workspace)) return;
      _isSaving = true;
      _notify();
      try {
        await _storage.save(next);
        _workspace = next;
      } finally {
        _isSaving = false;
        _notify();
      }
    });
    _writeQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
