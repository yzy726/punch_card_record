import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../providers/punch_provider.dart';
import '../utils/calendar_date.dart';

class PunchSheet extends StatefulWidget {
  const PunchSheet({super.key, required this.date});

  final DateTime date;

  @override
  State<PunchSheet> createState() => _PunchSheetState();
}

class _PunchSheetState extends State<PunchSheet> {
  bool _saving = false;
  String? _error;

  Future<void> _change(int delta) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<PunchProvider>().updatePunch(widget.date, delta);
    } on Object {
      if (mounted) setState(() => _error = '保存失败，请重试。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PunchProvider>();
    final count = provider.getCountForDate(widget.date);
    final isToday = sameCalendarDay(widget.date, provider.today);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isToday ? '今天的坚持' : '补记这一天',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(DateFormat('yyyy年M月d日 EEEE', 'zh_CN').format(widget.date)),
            const SizedBox(height: 20),
            Text('$count', style: const TextStyle(fontSize: 60, height: 1.15, fontWeight: FontWeight.w700, color: AppColors.primary)),
            const Text('次打卡', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('decrementPunch'),
                    onPressed: _saving || count == 0 ? null : () => _change(-1),
                    icon: const Icon(Icons.remove_rounded),
                    label: const Text('减少一次'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('incrementPunch'),
                    onPressed: _saving ? null : () => _change(1),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(_saving ? '保存中…' : '打卡 +1'),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }
}