import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:punch_card_record/models/punch_backup.dart';
import 'package:punch_card_record/models/punch_data.dart';
import 'package:punch_card_record/models/punch_record.dart';
import 'package:punch_card_record/providers/punch_provider.dart';

import 'test_support.dart';

void main() {
  late MemoryStorage storage;
  late PunchProvider provider;
  final now = DateTime(2026, 10, 18, 12);

  setUp(() async {
    storage = MemoryStorage();
    provider = PunchProvider(storageService: storage, clock: () => now);
    await provider.ready;
  });
  tearDown(() => provider.dispose());

  test('portable JSON includes settings, all counts and hidden logs', () async {
    await provider.updateSettings('阅读', 3);
    await provider.updatePunch(now, 2);
    await provider.softDeleteLog(provider.logs.first.id);
    final backup = PunchBackup.decode(await provider.exportBackup());
    expect(backup.data.punchName, '阅读');
    expect(backup.data.idealIntervalDays, 3);
    expect(backup.data.records.single.count, 2);
    expect(backup.data.logs.first.isDeleted, isTrue);
    expect(backup.exportedAt, now);
  });

  test('merge is idempotent for counts and keeps local settings', () async {
    await provider.updateSettings('阅读', 3);
    await provider.updatePunch(now, 2);
    final other = PunchBackup(
      exportedAt: now,
      data: PunchData(
        punchName: '运动',
        idealIntervalDays: 7,
        records: [
          PunchRecord(date: now, count: 3),
          PunchRecord(date: DateTime(2026, 10, 17), count: 1),
        ],
      ),
    );
    await provider.importBackup(other, replace: false);
    await provider.importBackup(other, replace: false);
    expect(provider.getCountForDate(now), 3);
    expect(provider.getCountForDate(DateTime(2026, 10, 17)), 1);
    expect(provider.monthTotal(now), 4);
    expect(provider.punchName, '阅读');
    expect(provider.idealIntervalDays, 3);
  });

  test(
    'merge deduplicates shared logs and preserves local hidden state',
    () async {
      await provider.updatePunch(now, 1);
      final original = PunchBackup.decode(await provider.exportBackup());
      final originalId = provider.logs.single.id;
      await provider.softDeleteLog(originalId);
      await provider.importBackup(original, replace: false);
      expect(provider.logs.where((log) => log.id == originalId).length, 1);
      expect(
        provider.logs.firstWhere((log) => log.id == originalId).isDeleted,
        isTrue,
      );
      expect(provider.getCountForDate(now), 1);
    },
  );

  test(
    'replace restores removals and settings instead of merging them',
    () async {
      await provider.updatePunch(now, 5);
      final backup = PunchBackup(
        exportedAt: now,
        data: PunchData(punchName: '运动', idealIntervalDays: 7),
      );
      await provider.importBackup(backup, replace: true);
      expect(provider.records, isEmpty);
      expect(provider.punchName, '运动');
      expect(provider.idealIntervalDays, 7);
      expect(provider.logs.single.action, '数据导入');
    },
  );

  test('failed import leaves all current data unchanged', () async {
    await provider.updatePunch(now, 2);
    final backup = PunchBackup(exportedAt: now, data: PunchData());
    storage.failNextSave = true;
    await expectLater(
      provider.importBackup(backup, replace: true),
      throwsStateError,
    );
    expect(provider.getCountForDate(now), 2);
    expect(provider.logs.length, 1);
  });

  test('invalid, unsupported and future backups cannot change data', () async {
    expect(() => PunchBackup.decode('{broken'), throwsFormatException);
    expect(
      () => PunchBackup.decode('{"format":"other","version":1}'),
      throwsFormatException,
    );
    final json =
        jsonDecode(PunchBackup(exportedAt: now, data: PunchData()).encode())
            as Map<String, dynamic>;
    json['version'] = 999;
    expect(() => PunchBackup.decode(jsonEncode(json)), throwsFormatException);
    final future = PunchBackup(
      exportedAt: now,
      data: PunchData(
        records: [PunchRecord(date: DateTime(2026, 10, 19), count: 1)],
      ),
    );
    await expectLater(
      provider.importBackup(future, replace: true),
      throwsFormatException,
    );
    expect(storage.writes, 0);
  });

  test('export waits for in-flight edits before taking its snapshot', () async {
    final edit = provider.updatePunch(now, 1);
    final export = provider.exportBackup();
    await edit;
    expect(PunchBackup.decode(await export).data.records.single.count, 1);
  });
}
