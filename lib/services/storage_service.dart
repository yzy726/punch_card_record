import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/punch_record.dart';
import '../models/punch_log.dart';

class StorageService {
  static const String _recordsFileName = 'punch_records.json';
  static const String _logsFileName = 'punch_logs.json';

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _recordsFile async {
    final path = await _localPath;
    return File('$path/$_recordsFileName');
  }

  Future<File> get _logsFile async {
    final path = await _localPath;
    return File('$path/$_logsFileName');
  }

  // --- Records ---

  Future<void> saveRecords(List<PunchRecord> records) async {
    final file = await _recordsFile;
    final String jsonString = jsonEncode(records.map((e) => e.toJson()).toList());
    await file.writeAsString(jsonString);
  }

  Future<List<PunchRecord>> loadRecords() async {
    try {
      final file = await _recordsFile;
      if (!await file.exists()) return [];
      final String contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((e) => PunchRecord.fromJson(e)).toList();
    } catch (e) {
      print("Error loading records: $e");
      return [];
    }
  }

  // --- Logs ---

  Future<void> saveLogs(List<PunchLog> logs) async {
    final file = await _logsFile;
    final String jsonString = jsonEncode(logs.map((e) => e.toJson()).toList());
    await file.writeAsString(jsonString);
  }

  Future<List<PunchLog>> loadLogs() async {
    try {
      final file = await _logsFile;
      if (!await file.exists()) return [];
      final String contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((e) => PunchLog.fromJson(e)).toList();
    } catch (e) {
      print("Error loading logs: $e");
      return [];
    }
  }
}