import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:punch_card_record/models/punch_backup.dart';
import 'package:punch_card_record/models/punch_data.dart';
import 'package:punch_card_record/models/punch_record.dart';
import 'package:punch_card_record/models/punch_workspace.dart';
import 'package:punch_card_record/providers/punch_provider.dart';

import 'test_support.dart';

void main() {
  final today = DateTime(2026, 10, 18, 0, 5);
  late MemoryStorage storage;
  late PunchProvider provider;
  setUp(() async {
    storage = MemoryStorage();
    provider = PunchProvider(storageService: storage, clock: () => today);
    await provider.ready;
  });
  tearDown(() => provider.dispose());

  test('each habit has independent settings, records, logs and statistics', () async {
    await provider.updateSettings('阅读', 2);
    await provider.updatePunch(today, 2);
    final readingId = provider.activeHabitId;
    await provider.createHabit('运动', 5);
    final exerciseId = provider.activeHabitId;
    expect(provider.records, isEmpty);
    expect(provider.idealIntervalDays, 5);
    await provider.updatePunch(today, 1);
    expect(provider.monthTotal(today), 1);
    expect(provider.getNextIdealDate(), DateTime(2026, 10, 23));
    await provider.selectHabit(readingId);
    expect(provider.punchName, '阅读');
    expect(provider.idealIntervalDays, 2);
    expect(provider.monthTotal(today), 2);
    expect(provider.getNextIdealDate(), DateTime(2026, 10, 20));
    expect(provider.logs.any((log) => log.action == '创建打卡'), isFalse);
    await provider.selectHabit(exerciseId);
    expect(provider.getCountForDate(today), 1);
  });

  test('projects and the active selection survive restarting', () async {
    await provider.createHabit('运动', 3);
    await provider.updatePunch(today, 1);
    final active = provider.activeHabitId;
    final restarted = PunchProvider(storageService: storage, clock: () => today);
    await restarted.ready;
    expect(restarted.habits.length, 2);
    expect(restarted.activeHabitId, active);
    expect(restarted.getCountForDate(today), 1);
    restarted.dispose();
  });

  test('duplicate names, blank names and invalid intervals are rejected', () async {
    await provider.createHabit('阅读', 2);
    for (final operation in [
      () => provider.createHabit(' 阅读 ', 3),
      () => provider.createHabit(' ', 1),
      () => provider.createHabit('运动', 0),
      () => provider.updateSettings('每日打卡', 2),
    ]) {
      await expectLater(operation(), throwsArgumentError);
    }
    expect(provider.habits.length, 2);
    expect(provider.punchName, '阅读');
  });

  test('queued punches stay attached to the project that received the tap', () async {
    await provider.createHabit('运动', 3);
    final exercise = provider.activeHabitId;
    await provider.selectHabit('legacy');
    final first = provider.updatePunch(today, 1);
    final switching = provider.selectHabit(exercise);
    final second = provider.updatePunch(today, 1);
    await Future.wait([first, switching, second]);
    expect(provider.activeHabitId, exercise);
    expect(provider.getCountForDate(today), 0);
    await provider.selectHabit('legacy');
    expect(provider.getCountForDate(today), 2);
  });

  test('failed project creation or switching never changes visible state', () async {
    storage.failNextSave = true;
    await expectLater(provider.createHabit('阅读', 2), throwsStateError);
    expect(provider.habits.length, 1);
    await provider.createHabit('阅读', 2);
    final reading = provider.activeHabitId;
    storage.failNextSave = true;
    await expectLater(provider.selectHabit('legacy'), throwsStateError);
    expect(provider.activeHabitId, reading);
  });

  test('deleting a project preserves other projects and the last project', () async {
    await provider.updatePunch(today, 2);
    await provider.createHabit('运动', 3);
    await provider.updatePunch(today, 1);
    await provider.deleteHabit(provider.activeHabitId);
    expect(provider.activeHabitId, 'legacy');
    expect(provider.getCountForDate(today), 2);
    await expectLater(provider.deleteHabit('legacy'), throwsStateError);
  });

  test('all projects export, merge by stable ID and never duplicate on reimport', () async {
    await provider.updatePunch(today, 1);
    await provider.createHabit('阅读', 2);
    final reading = provider.activeHabitId;
    await provider.updatePunch(today, 3);
    final backup = PunchBackup.decode(await provider.exportBackup());
    expect(backup.workspace.habits.length, 2);
    await provider.updateSettings('精读', 5);
    await provider.importBackup(backup, replace: false);
    await provider.importBackup(backup, replace: false);
    expect(provider.habits.length, 2);
    expect(provider.activeHabitId, reading);
    expect(provider.punchName, '精读');
    expect(provider.idealIntervalDays, 5);
    expect(provider.getCountForDate(today), 3);
    await provider.importBackup(backup, replace: true);
    expect(provider.punchName, '阅读');
    expect(provider.idealIntervalDays, 2);
    expect(provider.habits.length, 2);
  });

  test('new projects merge into another device and preserve its active project', () async {
    await provider.createHabit('运动', 3);
    await provider.updatePunch(today, 2);
    final backup = PunchBackup.decode(await provider.exportBackup());
    final other = PunchProvider(storageService: MemoryStorage(), clock: () => today);
    await other.ready;
    await other.importBackup(backup, replace: false);
    expect(other.habits.length, 2);
    expect(other.activeHabitId, 'legacy');
    await other.selectHabit(backup.workspace.activeHabitId);
    expect(other.getCountForDate(today), 2);
    other.dispose();
  });

  test('version 1 snapshots and portable backups retain their settings and counts', () {
    final old = PunchData(punchName: '旧项目', idealIntervalDays: 4, records: [PunchRecord(date: today, count: 7)]);
    final migrated = PunchWorkspace.fromJson(old.toJson());
    expect(migrated.habits.single.id, 'legacy');
    expect(migrated.active.data.records.single.count, 7);
    final backup = PunchBackup.decode(jsonEncode({
      'format': 'punch-card-record-backup', 'version': 1,
      'exportedAt': today.toIso8601String(), 'data': old.toJson(),
    }));
    expect(backup.data.punchName, '旧项目');
    expect(backup.data.idealIntervalDays, 4);
    expect(backup.data.records.single.count, 7);
  });

  test('invalid project IDs or active selection cannot be loaded', () {
    final habit = PunchHabit(id: 'same', data: PunchData());
    expect(() => PunchWorkspace(habits: [habit, habit], activeHabitId: 'same'), throwsFormatException);
    expect(() => PunchWorkspace(habits: [habit], activeHabitId: 'missing'), throwsFormatException);
  });
}
