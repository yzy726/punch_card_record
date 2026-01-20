import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/punch_provider.dart';

class LogPage extends StatelessWidget {
  const LogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("打卡日志"),
      ),
      body: Consumer<PunchProvider>(
        builder: (context, provider, child) {
          final logs = provider.logs.where((l) => !l.isDeleted).toList();

          if (logs.isEmpty) {
            return const Center(
              child: Text("暂无日志"),
            );
          }

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return Dismissible(
                key: Key(log.id),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  provider.softDeleteLog(log.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("记录已隐藏")),
                  );
                },
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(log.action),
                  subtitle: Text(
                    "${DateFormat('yyyy-MM-dd HH:mm').format(log.timestamp)}\n${log.details}",
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      provider.softDeleteLog(log.id);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}