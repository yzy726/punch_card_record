import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../models/punch_log.dart';
import '../providers/punch_provider.dart';
import '../utils/calendar_date.dart';

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  final Set<String> _busy = {};

  Future<void> _hide(PunchLog log) async {
    final provider = context.read<PunchProvider>();
    setState(() => _busy.add(log.id));
    try {
      await provider.softDeleteLog(log.id);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('日志已隐藏，打卡记录不受影响'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => _restore(log.id),
          ),
        ),
      );
    } on Object {
      if (mounted) _error();
    } finally {
      if (mounted) setState(() => _busy.remove(log.id));
    }
  }

  Future<void> _restore(String id) async {
    try {
      await context.read<PunchProvider>().restoreLog(id);
    } on Object {
      if (mounted) _error();
    }
  }

  void _error() => ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('保存失败，请重试。')));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PunchProvider>();
    final logs = provider.logs.where((log) => !log.isDeleted).toList();
    return Scaffold(
      appBar: AppBar(title: Text('${provider.punchName} · 日志', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: logs.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 56,
                            color: AppColors.muted,
                          ),
                          SizedBox(height: 20),
                          Text(
                            '还没有可见的日志',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            '完成一次打卡，故事就从这里开始。',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: logs.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 20),
                          child: Text(
                            '每一份坚持，都有迹可循。\n隐藏日志不会删除打卡次数。',
                            style: TextStyle(
                              color: AppColors.muted,
                              height: 1.7,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }
                      final log = logs[index - 1];
                      final newDay =
                          index == 1 ||
                          !sameCalendarDay(
                            logs[index - 2].timestamp,
                            log.timestamp,
                          );
                      final setting = log.action == '设置更新';
                      final decrease = log.action.startsWith('打卡 -');
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (newDay)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 12,
                                top: 4,
                              ),
                              child: Text(
                                DateFormat(
                                  'M月d日 EEEE',
                                  'zh_CN',
                                ).format(log.timestamp),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  18,
                                  4,
                                  18,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.pale,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        setting
                                            ? Icons.tune_rounded
                                            : decrease
                                            ? Icons.remove_rounded
                                            : Icons.check_rounded,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            log.action,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            log.details,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.muted,
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          Text(
                                            DateFormat(
                                              'HH:mm:ss',
                                            ).format(log.timestamp),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '隐藏日志',
                                      icon: const Icon(
                                        Icons.visibility_off_outlined,
                                        size: 19,
                                        color: AppColors.muted,
                                      ),
                                      onPressed: _busy.contains(log.id)
                                          ? null
                                          : () => _hide(log),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
