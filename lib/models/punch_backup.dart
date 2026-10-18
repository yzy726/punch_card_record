import 'dart:convert';

import 'punch_data.dart';
import 'punch_workspace.dart';

class PunchBackup {
  PunchBackup({PunchData? data, PunchWorkspace? workspace, required this.exportedAt})
      : workspace = workspace ?? PunchWorkspace.single(data ?? PunchData());

  static const maxBytes = 10 * 1024 * 1024;
  final PunchWorkspace workspace;
  final DateTime exportedAt;
  PunchData get data => workspace.active.data;

  String encode() => const JsonEncoder.withIndent('  ').convert({
    'format': 'punch-card-record-backup',
    'version': 2,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'workspace': workspace.toJson(),
  });

  factory PunchBackup.decode(String contents) {
    if (utf8.encode(contents).length > maxBytes) {
      throw const FormatException('备份文件不能超过 10 MB');
    }
    try {
      final json = jsonDecode(contents) as Map<String, dynamic>;
      if (json['format'] != 'punch-card-record-backup' ||
          (json['version'] != 1 && json['version'] != 2)) {
        throw const FormatException('请选择打卡记导出的有效 JSON 备份');
      }
      final workspace = json['version'] == 1
          ? PunchWorkspace.single(PunchData.fromJson(json['data'] as Map<String, dynamic>))
          : PunchWorkspace.fromJson(json['workspace'] as Map<String, dynamic>);
      for (final habit in workspace.habits) {
        if (habit.data.logs.map((log) => log.id).toSet().length != habit.data.logs.length) {
          throw const FormatException('备份中存在重复的日志编号');
        }
      }
      return PunchBackup(
        workspace: workspace,
        exportedAt: DateTime.parse(json['exportedAt'] as String).toLocal(),
      );
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('备份内容不完整，请选择打卡记导出的 JSON 文件');
    }
  }
}