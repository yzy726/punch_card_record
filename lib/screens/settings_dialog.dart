import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/punch_provider.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.provider,
    this.create = false,
  });

  final PunchProvider provider;
  final bool create;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.create ? '' : widget.provider.punchName,
  );
  late final _interval = TextEditingController(
    text: widget.create ? '1' : widget.provider.idealIntervalDays.toString(),
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.create) {
        await widget.provider.createHabit(
          _name.text,
          int.parse(_interval.text),
        );
      } else {
        await widget.provider.updateSettings(
          _name.text,
          int.parse(_interval.text),
        );
      }
      if (mounted) Navigator.pop(context);
    } on ArgumentError catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message.toString();
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存失败，请重试。';
        });
      }
    }
  }

  Future<void> _delete() async {
    final id = widget.provider.activeHabitId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('删除「${widget.provider.punchName}」？'),
        content: const Text('此项目的打卡记录和日志将一并删除，其他项目不受影响。建议先导出备份。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.provider.deleteHabit(id);
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '删除失败，请重试。';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.create ? '新建打卡' : '让打卡适合你'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('给坚持起个名字，找到自己的节奏。'),
            const SizedBox(height: 24),
            TextFormField(
              key: const Key('punchNameField'),
              controller: _name,
              enabled: !_saving,
              maxLength: 30,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: '打卡名称'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return '请输入打卡名称';
                if (value.trim().runes.length > 30) return '名称不能超过 30 个字符';
                return widget.provider.habits.any(
                      (habit) =>
                          (widget.create ||
                              habit.id != widget.provider.activeHabitId) &&
                          habit.data.punchName.toLowerCase() ==
                              value.trim().toLowerCase(),
                    )
                    ? '已存在同名打卡，请换一个名称'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('intervalField'),
              controller: _interval,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '理想间隔',
                suffixText: '天',
                helperText: '1–365 天，用于计算下次理想日期',
              ),
              validator: (value) {
                final interval = int.tryParse(value ?? '');
                return interval == null || interval < 1 || interval > 365
                    ? '请输入 1–365 之间的整数'
                    : null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (!widget.create && widget.provider.habits.length > 1) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除此打卡'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(
          _saving
              ? '保存中…'
              : widget.create
              ? '创建'
              : '保存',
        ),
      ),
    ],
  );
}
