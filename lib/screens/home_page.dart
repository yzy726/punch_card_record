import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../app_theme.dart';
import '../providers/punch_provider.dart';
import '../utils/calendar_date.dart';
import 'backup_page.dart';
import 'log_page.dart';
import 'punch_sheet.dart';
import 'settings_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  CalendarFormat _format = CalendarFormat.month;
  DateTime? _focusedDay;
  DateTime? _selectedDay;
  DateTime? _displayedToday;
  Timer? _midnightTimer;
  bool _quickSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final today = context.read<PunchProvider>().today;
    _focusedDay ??= today;
    _selectedDay ??= today;
    _displayedToday ??= today;
  }

  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(
      midnight.difference(now) + const Duration(milliseconds: 50),
      () {
        _refreshDay();
        _scheduleMidnight();
      },
    );
  }

  void _refreshDay() {
    if (!mounted) return;
    final today = context.read<PunchProvider>().today;
    setState(() {
      if (_selectedDay == _displayedToday) {
        _selectedDay = today;
        _focusedDay = today;
      }
      _displayedToday = today;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDay();
      _scheduleMidnight();
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _message(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _punchToday(PunchProvider provider) async {
    setState(() => _quickSaving = true);
    try {
      final day = provider.today;
      await provider.updatePunch(day, 1);
      if (!mounted) return;
      setState(() {
        _selectedDay = day;
        _focusedDay = day;
      });
      _message('已记下今天的第 ${provider.getCountForDate(day)} 次坚持');
    } on Object {
      if (mounted) _message('保存失败，请重试。');
    } finally {
      if (mounted) setState(() => _quickSaving = false);
    }
  }

  void _selectDay(DateTime selected, DateTime focused, PunchProvider provider) {
    if (provider.isFutureDate(selected)) {
      _message('不能提前打卡未来的日期');
      return;
    }
    setState(() {
      _selectedDay = calendarDate(selected);
      _focusedDay = calendarDate(focused);
    });
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => PunchSheet(date: calendarDate(selected)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PunchProvider>();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.spa_rounded, color: AppColors.primary, size: 25),
            SizedBox(width: 9),
            Text('打卡记', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('backupButton'),
            tooltip: '导出与导入',
            icon: const Icon(Icons.sync_alt_rounded),
            onPressed: provider.isLoading || provider.loadError != null
                ? null
                : () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const BackupPage())),
          ),
          IconButton(
            tooltip: '打卡日志',
            icon: const Icon(Icons.history_rounded),
            onPressed: provider.isLoading || provider.loadError != null
                ? null
                : () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const LogPage())),
          ),
          IconButton(
            key: const Key('settingsButton'),
            tooltip: '打卡设置',
            icon: const Icon(Icons.tune_rounded),
            onPressed: provider.isLoading || provider.loadError != null || provider.isSaving
                ? null
                : () => showDialog<void>(context: context, builder: (_) => SettingsDialog(provider: provider)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.loadError != null
              ? _loadError(provider)
              : SafeArea(
                  top: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: ListView(
                        key: const Key('homeScroll'),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          if (provider.recoveryMessage != null) ...[
                            Card(
                              color: const Color(0xFFFFF2D5),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(provider.recoveryMessage!),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _hero(provider),
                          const SizedBox(height: 20),
                          _statistics(provider),
                          const SizedBox(height: 20),
                          _calendar(provider),
                          const SizedBox(height: 16),
                          _nextDate(provider),
                          const SizedBox(height: 24),
                          const Text(
                            '数据保存在本机 · 每一次记录都算数',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _loadError(PunchProvider provider) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.muted),
              const SizedBox(height: 20),
              Text(provider.loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(onPressed: provider.retryLoad, child: const Text('重新读取')),
            ],
          ),
        ),
      );

  Widget _hero(PunchProvider provider) {
    final count = provider.getCountForDate(provider.today);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF234E43), Color(0xFF337D65)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(DateFormat('M月d日 EEEE', 'zh_CN').format(provider.today), style: const TextStyle(color: Color(0xFFC5DACE), fontSize: 13)),
              ),
              const Icon(Icons.auto_awesome_rounded, size: 21, color: AppColors.lime),
            ],
          ),
          const SizedBox(height: 16),
          Text(provider.punchName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 28, height: 1.25, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(count == 0 ? '不必很快，今天也向前一点。' : '今天已打卡 $count 次，继续按自己的节奏。', style: const TextStyle(color: Color(0xFFD9E7DD), fontSize: 13, height: 1.5)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('todayPunchButton'),
              onPressed: _quickSaving || provider.isSaving ? null : () => _punchToday(provider),
              style: FilledButton.styleFrom(backgroundColor: AppColors.lime, foregroundColor: AppColors.ink),
              icon: Icon(count == 0 ? Icons.add_rounded : Icons.check_circle_outline_rounded),
              label: Text(_quickSaving ? '正在保存…' : count == 0 ? '今日打卡' : '再打卡一次', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statistics(PunchProvider provider) => Row(
        children: [
          _stat('本月次数', provider.monthTotal(_focusedDay!), '次'),
          const SizedBox(width: 10),
          _stat('打卡天数', provider.monthActiveDays(_focusedDay!), '天'),
          const SizedBox(width: 10),
          _stat('连续天数', provider.currentStreak, '天'),
        ],
      );

  Widget _stat(String label, int value, String unit) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 17),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '$value', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    TextSpan(text: ' $unit', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ])),
                ),
                const SizedBox(height: 5),
                FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted))),
              ],
            ),
          ),
        ),
      );

  DateTime _firstDay(PunchProvider provider) => DateTime(
        provider.records.isNotEmpty && provider.records.first.date.year < 1970
            ? provider.records.first.date.year
            : 1970,
      );

  Widget _calendar(PunchProvider provider) {
    final first = _firstDay(provider);
    final last = DateTime(provider.today.year + 20, 12, 31);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 6)),
                    onPressed: () => _pickYear(provider),
                    child: Text(DateFormat('yyyy年M月', 'zh_CN').format(_focusedDay!), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
                IconButton(
                  tooltip: '上个月',
                  onPressed: () => _moveMonth(-1, first, last),
                  icon: const Icon(Icons.chevron_left_rounded),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: '下个月',
                  onPressed: () => _moveMonth(1, first, last),
                  icon: const Icon(Icons.chevron_right_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() {
                    _focusedDay = provider.today;
                    _selectedDay = provider.today;
                  }),
                  icon: const Icon(Icons.my_location_rounded, size: 15),
                  label: const Text('回到今天', style: TextStyle(fontSize: 12)),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _format = _format == CalendarFormat.month ? CalendarFormat.week : CalendarFormat.month),
                  icon: Icon(_format == CalendarFormat.month ? Icons.view_week_outlined : Icons.calendar_month_outlined, size: 16),
                  label: Text(_format == CalendarFormat.month ? '周视图' : '月视图', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            TableCalendar<void>(
              locale: 'zh_CN',
              firstDay: first,
              lastDay: last,
              focusedDay: _focusedDay!,
              currentDay: provider.today,
              calendarFormat: _format,
              availableCalendarFormats: const {CalendarFormat.month: '月', CalendarFormat.week: '周'},
              headerVisible: false,
              startingDayOfWeek: StartingDayOfWeek.monday,
              rowHeight: 52,
              daysOfWeekHeight: 30,
              selectedDayPredicate: (day) => _selectedDay != null && sameCalendarDay(_selectedDay!, day),
              onDaySelected: (selected, focused) => _selectDay(selected, focused, provider),
              onPageChanged: (day) => setState(() => _focusedDay = calendarDate(day)),
              onFormatChanged: (format) => setState(() => _format = format),
              daysOfWeekStyle: const DaysOfWeekStyle(weekdayStyle: TextStyle(color: AppColors.muted, fontSize: 12), weekendStyle: TextStyle(color: AppColors.muted, fontSize: 12)),
              calendarBuilders: CalendarBuilders<void>(
                defaultBuilder: (_, day, __) => _dayCell(day, provider),
                todayBuilder: (_, day, __) => _dayCell(day, provider),
                selectedBuilder: (_, day, __) => _dayCell(day, provider),
                outsideBuilder: (_, day, __) => _dayCell(day, provider, outside: true),
              ),
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 18,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _Legend(color: AppColors.primary, label: '已打卡'),
                _Legend(color: AppColors.lime, label: '理想日期'),
                _Legend(color: Color(0xFFDDE4DF), label: '点击日期补记'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(DateTime day, PunchProvider provider, {bool outside = false}) {
    final count = provider.getCountForDate(day);
    final selected = _selectedDay != null && sameCalendarDay(_selectedDay!, day);
    final today = sameCalendarDay(day, provider.today);
    final next = provider.getNextIdealDate();
    final ideal = next != null && sameCalendarDay(day, next);
    final future = provider.isFutureDate(day);
    final foreground = selected ? Colors.white : outside || future ? AppColors.muted : AppColors.ink;
    return Semantics(
      button: true,
      label: '${day.month}月${day.day}日，打卡$count次',
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : count > 0 ? AppColors.pale : ideal ? AppColors.lime.withValues(alpha: 0.55) : null,
          borderRadius: BorderRadius.circular(12),
          border: today && !selected ? Border.all(color: AppColors.primary) : null,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${day.day}', textScaler: TextScaler.noScaling, style: TextStyle(color: foreground, fontSize: 14, fontWeight: selected || today || count > 0 ? FontWeight.w700 : FontWeight.w400)),
              const SizedBox(height: 2),
              SizedBox(
                height: 12,
                child: count > 0
                    ? Text(count > 99 ? '99+' : '$count次', textScaler: TextScaler.noScaling, style: TextStyle(color: selected ? const Color(0xFFDDEEBA) : AppColors.primary, fontSize: 9, fontWeight: FontWeight.w600))
                    : today
                        ? Text('今天', textScaler: TextScaler.noScaling, style: TextStyle(fontSize: 8, color: foreground))
                        : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _moveMonth(int delta, DateTime first, DateTime last) {
    final day = _focusedDay!;
    final next = _format == CalendarFormat.week
        ? DateTime(day.year, day.month, day.day + 7 * delta)
        : DateTime(day.year, day.month + delta);
    if (next.isBefore(first) || next.isAfter(last)) return;
    setState(() => _focusedDay = next);
  }

  Future<void> _pickYear(PunchProvider provider) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('选择年份'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: YearPicker(
              firstDate: _firstDay(provider),
              lastDate: DateTime(provider.today.year + 20, 12, 31),
              selectedDate: _focusedDay!,
              onChanged: (date) {
                setState(() => _focusedDay = DateTime(date.year, _focusedDay!.month));
                Navigator.pop(dialogContext);
              },
            ),
          ),
        ),
      );

  Widget _nextDate(PunchProvider provider) {
    final next = provider.getNextIdealDate();
    final gap = next == null ? null : calendarDaysBetween(provider.today, next);
    final label = next == null ? '你的第一步，从今天开始' : gap! < 0 ? '理想日期已过，随时可以继续' : gap == 0 ? '今天正好，记下这份坚持' : '下一次，继续向前';
    return Card(
      color: AppColors.pale,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.event_available_rounded, color: AppColors.primary, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 13, color: AppColors.primary)),
                  const SizedBox(height: 7),
                  Text(next == null ? '每一点努力，都值得被记录' : DateFormat('M月d日 EEEE', 'zh_CN').format(next), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 7),
                  Text('理想间隔 ${provider.idealIntervalDays} 天 · 按自己的节奏来', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        ],
      );
}
