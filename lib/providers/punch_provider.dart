import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/punch_record.dart';
import '../models/punch_log.dart';
import '../services/storage_service.dart';

class PunchProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  final Uuid _uuid = const Uuid();

  List<PunchRecord> _records = [];
  List<PunchLog> _logs = [];
  
  String _punchName = "每日打卡";
  int _idealIntervalDays = 1;

  List<PunchRecord> get records => _records;
  List<PunchLog> get logs => _logs;
  String get punchName => _punchName;
  int get idealIntervalDays => _idealIntervalDays;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  PunchProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    // Load Settings
    final prefs = await SharedPreferences.getInstance();
    _punchName = prefs.getString('punchName') ?? "每日打卡";
    _idealIntervalDays = prefs.getInt('idealIntervalDays') ?? 1;

    // Load Data
    _records = await _storageService.loadRecords();
    _logs = await _storageService.loadLogs();

    _isLoading = false;
    notifyListeners();
  }

  // --- Settings ---

  Future<void> updateSettings(String name, int interval) async {
    _punchName = name;
    _idealIntervalDays = interval;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('punchName', name);
    await prefs.setInt('idealIntervalDays', interval);
    
    _addLog("设置更新", "名称: $name, 间隔: $interval 天");
    notifyListeners();
  }

  // --- Punch Logic ---

  int getCountForDate(DateTime date) {
    final record = _records.firstWhere(
      (r) => isSameDay(r.date, date),
      orElse: () => PunchRecord(date: date, count: 0),
    );
    return record.count;
  }

  Future<void> updatePunch(DateTime date, int change) async {
    final index = _records.indexWhere((r) => isSameDay(r.date, date));
    int newCount;
    
    if (index != -1) {
      newCount = _records[index].count + change;
      if (newCount < 0) newCount = 0; // Prevent negative
      
      if (newCount == 0) {
        _records.removeAt(index);
      } else {
        _records[index] = PunchRecord(date: date, count: newCount);
      }
    } else {
      newCount = change > 0 ? change : 0;
      if (newCount > 0) {
        _records.add(PunchRecord(date: date, count: newCount));
      }
    }

    await _storageService.saveRecords(_records);
    
    String action = change > 0 ? "打卡 +$change" : "打卡 $change";
    _addLog(action, "日期: ${date.toString().split(' ')[0]}, 新数量: $newCount");
    
    notifyListeners();
  }

  // --- Log Logic ---

  void _addLog(String action, String details) {
    final log = PunchLog(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      action: action,
      details: details,
    );
    _logs.insert(0, log); // Add to top
    _storageService.saveLogs(_logs);
  }

  Future<void> softDeleteLog(String id) async {
    final index = _logs.indexWhere((l) => l.id == id);
    if (index != -1) {
      _logs[index].isDeleted = true;
      // We don't save the 'isDeleted' state to file to keep history intact in file, 
      // but requirement says "store in file but delete from surface".
      // So we actually need to save the isDeleted state to file so it persists across restarts.
      await _storageService.saveLogs(_logs);
      notifyListeners();
    }
  }

  // --- Helpers ---
  
  DateTime? getLastPunchDate() {
    if (_records.isEmpty) return null;
    // Sort records by date descending
    final sorted = List<PunchRecord>.from(_records)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.first.date;
  }

  DateTime? getNextIdealDate() {
    final last = getLastPunchDate();
    if (last == null) return null;
    return last.add(Duration(days: _idealIntervalDays));
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}