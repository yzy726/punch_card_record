import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../models/punch_backup.dart';
import '../providers/punch_provider.dart';
import '../services/backup_file_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key, this.files});

  final BackupFileService? files;

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  late final _files = widget.files ?? BackupFileService();
  bool _busy = false;

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _export({bool share = false}) async {
    setState(() => _busy = true);
    try {
      final contents = await context.read<PunchProvider>().exportBackup();
      final filename =
          'punch-card-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}.json';
      if (share) {
        await _files.shareFile(contents, filename);
      } else {
        final saved = await _files.exportFile(contents, filename);
        if (mounted && saved) _message('备份已导出，可传到另一台设备导入');
      }
    } on Object {
      if (mounted) _message('导出失败，请检查保存位置后重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final backup = await _files.pickBackup();
      if (backup == null || !mounted) return;
      setState(() => _busy = false);
      final replace = await showDialog<bool>(
        context: context,
        builder: (_) => _ImportPreview(backup: backup),
      );
      if (replace == null || !mounted) return;
      if (replace) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('覆盖当前数据？'),
            content: const Text('本机所有打卡项目、设置和日志将替换为备份中的内容。建议先导出当前数据。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('确认覆盖'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      setState(() => _busy = true);
      await context.read<PunchProvider>().importBackup(
        backup,
        replace: replace,
      );
      if (mounted) _message(replace ? '已用备份恢复数据' : '合并完成，重复导入不会累加同一天的次数');
    } on FormatException catch (error) {
      if (mounted) _message(error.message);
    } on Object {
      if (mounted) _message('导入失败，当前数据未更改。请检查备份文件后重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PunchProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('导出与导入')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  color: AppColors.pale,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.devices_rounded,
                          color: AppColors.primary,
                          size: 36,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '把坚持，带到另一台设备',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '在这台设备导出或分享 JSON 备份，\n再到另一台设备点击「导入数据」。',
                          style: TextStyle(height: 1.7),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '本机共 ${provider.habits.length} 个打卡项目 · ${provider.habits.fold<int>(0, (sum, habit) => sum + habit.data.records.length)} 条日记录',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('exportDataButton'),
                  onPressed: _busy ? null : () => _export(),
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('导出数据'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('shareDataButton'),
                  onPressed: _busy ? null : () => _export(share: true),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('分享备份到其他设备'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('importDataButton'),
                  onPressed: _busy ? null : _import,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('导入数据'),
                ),
                if (_busy) ...[
                  const SizedBox(height: 20),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 28),
                const Text(
                  '关于合并',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  '备份包含全部项目。同一项目按日期取较大次数，保留本机设置和日志。改名后的项目仍会匹配；不同设备独立创建的同名项目会分别保留。',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '若需要同步减少次数、删除项目或设置变更，请用最新备份覆盖。此功能通过文件手动同步，不会自动上传数据。',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '备份包含全部打卡、设置和日志（含隐藏日志），请只分享给信任的设备。',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImportPreview extends StatefulWidget {
  const _ImportPreview({required this.backup});

  final PunchBackup backup;

  @override
  State<_ImportPreview> createState() => _ImportPreviewState();
}

class _ImportPreviewState extends State<_ImportPreview> {
  bool _replace = false;

  @override
  Widget build(BuildContext context) {
    final backup = widget.backup;
    final count = backup.workspace.habits.expand((habit) => habit.data.records).fold<int>(
      0,
      (sum, record) => sum + record.count,
    );
    return AlertDialog(
      title: const Text('预览导入数据'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${backup.workspace.habits.length} 个打卡项目',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '$count 次打卡 · ${backup.workspace.habits.fold<int>(0, (sum, habit) => sum + habit.data.logs.length)} 条日志（含隐藏日志）',
              style: const TextStyle(height: 1.7),
            ),
            ...backup.workspace.habits.map((habit) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${habit.data.punchName} · 间隔 ${habit.data.idealIntervalDays} 天', style: const TextStyle(fontSize: 13)),
            )),
            const SizedBox(height: 8),
            Text(
              '导出于 ${DateFormat('yyyy-MM-dd HH:mm').format(backup.exportedAt)}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              title: const Text('合并到当前数据'),
              subtitle: const Text('同日取较大次数，保留本机设置'),
              value: false,
              groupValue: _replace,
              onChanged: (_) => setState(() => _replace = false),
            ),
            RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              title: const Text('覆盖当前数据'),
              subtitle: const Text('完整恢复此备份，包含设置和日志'),
              value: true,
              groupValue: _replace,
              onChanged: (_) => setState(() => _replace = true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _replace),
          child: const Text('确认导入'),
        ),
      ],
    );
  }
}
