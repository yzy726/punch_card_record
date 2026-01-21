import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/punch_provider.dart';
import 'log_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return Consumer<PunchProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onTap: () => _showSettingsDialog(context, provider),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(provider.punchName),
                  const SizedBox(width: 8),
                  const Icon(Icons.edit, size: 16),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_today_outlined),
                tooltip: '选择年份',
                onPressed: () => _showYearPicker(context),
              ),
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LogPage()),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                onFormatChanged: (format) {
                  // Do nothing to prevent format change
                },
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  if (selectedDay.isAfter(DateTime.now())) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("不能预打卡未来的日期！")),
                    );
                    return;
                  }
                  
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  _showPunchDialog(context, provider, selectedDay);
                },
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                },
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                },
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    return _buildDayCell(context, day, provider);
                  },
                  todayBuilder: (context, day, focusedDay) {
                     return _buildDayCell(context, day, provider, isToday: true);
                  },
                  selectedBuilder: (context, day, focusedDay) {
                     return _buildDayCell(context, day, provider, isSelected: true);
                  },
                ),
              ),
              const SizedBox(height: 20),
              if (provider.getLastPunchDate() != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text("下次理想打卡日期", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('yyyy-MM-dd').format(provider.getNextIdealDate()!),
                            style: const TextStyle(fontSize: 20, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDayCell(BuildContext context, DateTime day, PunchProvider provider, {bool isToday = false, bool isSelected = false}) {
    final count = provider.getCountForDate(day);
    final lastPunch = provider.getLastPunchDate();
    final nextIdeal = provider.getNextIdealDate();
    
    bool isIdealRange = false;
    if (lastPunch != null && nextIdeal != null) {
      // Check if day is strictly between lastPunch and nextIdeal (inclusive of nextIdeal, exclusive of lastPunch)
      // Or whatever logic fits "interval". Let's say [Last+1, NextIdeal]
      if (day.isAfter(lastPunch) && !day.isAfter(nextIdeal)) {
        isIdealRange = true;
      }
    }

    Color? bgColor;
    if (isSelected) {
      bgColor = Colors.blue.shade300;
    } else if (isToday) {
      bgColor = Colors.blue.shade100;
    } else if (isIdealRange) {
      bgColor = Colors.green.shade50;
    }

    return Container(
      margin: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: isToday ? Border.all(color: Colors.blue, width: 2) : null,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (count > 0)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPunchDialog(BuildContext context, PunchProvider provider, DateTime date) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("${DateFormat('MM-dd').format(date)} 打卡"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("当前数量: ${provider.getCountForDate(date)}", style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      provider.updatePunch(date, -1);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100),
                    child: const Text("-1", style: TextStyle(color: Colors.red)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      provider.updatePunch(date, 1);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade100),
                    child: const Text("+1", style: TextStyle(color: Colors.green)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSettingsDialog(BuildContext context, PunchProvider provider) {
    final nameController = TextEditingController(text: provider.punchName);
    final intervalController = TextEditingController(text: provider.idealIntervalDays.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("设置"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "打卡名称"),
              ),
              TextField(
                controller: intervalController,
                decoration: const InputDecoration(labelText: "理想间隔天数"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("取消"),
            ),
            TextButton(
              onPressed: () {
                final interval = int.tryParse(intervalController.text) ?? 1;
                provider.updateSettings(nameController.text, interval);
                Navigator.pop(context);
              },
              child: const Text("保存"),
            ),
          ],
        );
      },
    );
  }
  
    void _showYearPicker(BuildContext context) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("选择年份"),
            content: SizedBox(
              width: 300,
              height: 300,
              child: YearPicker(
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                selectedDate: _focusedDay,
                onChanged: (DateTime dateTime) {
                  setState(() {
                    _focusedDay = dateTime;
                  });
                  Navigator.of(context).pop();
                },
              ),
            ),
          );
        },
      );
    }
}