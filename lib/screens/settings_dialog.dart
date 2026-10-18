import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/punch_provider.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.provider});

  final PunchProvider provider;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.provider.punchName);
  late final _interval = TextEditingController(
    text: widget.provider.idealIntervalDays.toString(),
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
      await widget.provider.updateSettings(
        _name.text,
        int.parse(_interval.text),
      );
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存失败，请重试。';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('让打卡适合你'),
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
                  validator: (value) => value == null || value.trim().isEmpty
                      ? '请输入打卡名称'
                      : null,
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
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ],
      );
}