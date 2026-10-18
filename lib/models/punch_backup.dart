import 'dart:convert';

import 'punch_data.dart';

class PunchBackup {
  const PunchBackup({required this.data, required this.exportedAt});

  static const maxBytes = 10 * 1024 * 1024;
  final PunchData data;
  final DateTime exportedAt;

  String encode() => const JsonEncoder.withIndent('  ').convert({
    'format': 'punch-card-record-backup',
    'version': 1,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'data': data.toJson(),
  });

  factory PunchBackup.decode(String contents) {
    if (utf8.encode(contents).length > maxBytes) {
      throw const FormatException('备份文件不能超过 10 MB');
    }
    try {
      final json = jsonDecode(contents) as Map<String, dynamic>;
      if (json['format'] != 'punch-card-record-backup' ||
          json['version'] != 1) {
        throw const FormatException('请选择打卡记导出的有效 JSON 备份');
      }
      final data = PunchData.fromJson(json['data'] as Map<String, dynamic>);
      if (data.logs.map((log) => log.id).toSet().length != data.logs.length) {
        throw const FormatException('备份中存在重复的日志编号');
      }
      return PunchBackup(
        data: data,
        exportedAt: DateTime.parse(json['exportedAt'] as String).toLocal(),
      );
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('备份内容不完整，请选择打卡记导出的 JSON 文件');
    }
  }
}
