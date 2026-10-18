import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/punch_backup.dart';

class BackupFileService {
  Future<bool> exportFile(String contents, String filename) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出打卡备份',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: Uint8List.fromList(utf8.encode(contents)),
    );
    return path != null;
  }

  Future<PunchBackup?> pickBackup() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择打卡备份',
      type: FileType.any,
      allowMultiple: false,
      withData: false,
    );
    if (result == null) return null;
    final selected = result.files.single;
    if (selected.size > PunchBackup.maxBytes) {
      throw const FormatException('备份文件不能超过 10 MB');
    }
    final path = selected.path;
    if (path == null) throw const FormatException('无法读取这个文件，请先保存到本机');
    final file = File(path);
    if (await file.length() > PunchBackup.maxBytes) {
      throw const FormatException('备份文件不能超过 10 MB');
    }
    return PunchBackup.decode(await file.readAsString());
  }

  Future<void> shareFile(String contents, String filename) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(contents, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: '打卡记数据备份',
      ),
    );
  }
}
