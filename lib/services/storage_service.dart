import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/punch_data.dart';
import '../models/punch_log.dart';
import '../models/punch_record.dart';

class StorageService {
  StorageService({Directory? directory}) : _directory = directory;

  final Directory? _directory;
  bool _primaryHealthy = false;
  String? recoveryMessage;

  Future<Directory> get _localDirectory async =>
      _directory ?? await getApplicationDocumentsDirectory();

  Future<PunchData> load() async {
    recoveryMessage = null;
    final directory = await _localDirectory;
    final primary = File('${directory.path}/punch_data.json');
    final backup = File('${primary.path}.bak');
    final primaryExists = await primary.exists();
    final backupExists = await backup.exists();
    if (primaryExists || backupExists) {
      try {
        final data = await _readSnapshot(primary);
        _primaryHealthy = true;
        return data;
      } on Object {
        _primaryHealthy = false;
        try {
          final data = await _readSnapshot(backup);
          recoveryMessage = '数据文件读取异常，已恢复上一次成功保存的备份。';
          return data;
        } on Object {
          throw const FileSystemException('数据和备份均无法读取，原始文件已保留');
        }
      }
    }

    // Keep the old files intact; migrate on the first successful edit.
    final records = await _readLegacy(
      File('${directory.path}/punch_records.json'),
      PunchRecord.fromJson,
    );
    final logs = await _readLegacy(
      File('${directory.path}/punch_logs.json'),
      PunchLog.fromJson,
    );
    final preferences = await SharedPreferences.getInstance();
    final name = preferences.getString('punchName')?.trim() ?? '';
    final interval = preferences.getInt('idealIntervalDays') ?? 1;
    return PunchData(
      records: records,
      logs: logs,
      punchName: name.isEmpty ? '每日打卡' : name,
      idealIntervalDays: interval.clamp(1, 365).toInt(),
    );
  }

  Future<void> save(PunchData data) async {
    final directory = await _localDirectory;
    await directory.create(recursive: true);
    final primary = File('${directory.path}/punch_data.json');
    final temporary = File('${primary.path}.tmp');
    final backup = File('${primary.path}.bak');
    final contents = jsonEncode(data.toJson());
    await temporary.writeAsString(contents, flush: true);
    // A corrupt primary must never overwrite the healthy recovery copy.
    if (_primaryHealthy && await primary.exists()) {
      await primary.copy(backup.path);
    } else if (!await backup.exists()) {
      await temporary.copy(backup.path);
    }
    await temporary.rename(primary.path);
    _primaryHealthy = true;
  }

  Future<PunchData> _readSnapshot(File file) async => PunchData.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );

  Future<List<T>> _readLegacy<T>(
    File file,
    T Function(Map<String, dynamic>) decode,
  ) async {
    if (!await file.exists()) return [];
    final contents = jsonDecode(await file.readAsString()) as List<dynamic>;
    return contents
        .map((item) => decode(item as Map<String, dynamic>))
        .toList();
  }
}
