import 'package:flutter_test/flutter_test.dart';
import 'package:punch_card_record/models/punch_data.dart';
import 'package:punch_card_record/models/punch_record.dart';
import 'package:punch_card_record/providers/punch_provider.dart';

import 'test_support.dart';

void main() {
  late MemoryStorage storage;
  late PunchProvider provider;
  late DateTime now;

  setUp(() async {
    now = DateTime(2026, 10, 18, 0, 5);
    storage = MemoryStorage();
    provider = PunchProvider(storageService: storage, clock: () => now);
    await provider.ready;
  });

  tearDown(() => provider.dispose());

  test('accepts the UTC calendar cell for today at 00:05 local time', () async {
    final cell = DateTime.utc(2026, 10, 18);
    await provider.updatePunch(cell, 1);
    expect(provider.getCountForDate(now), 1);
    expect(provider.records.single.date, DateTime(2026, 10, 18));
    expect(storage.data.logs.single.action, '打卡 +1');
  });

  test('future date rejection is enforced outside the UI too', () async {
    await expectLater(
      provider.updatePunch(DateTime.utc(2026, 10, 19), 1),
      throwsArgumentError,
    );
    expect(storage.writes, 0);
    expect(provider.logs, isEmpty);
  });

  test(
    'zero decrements are no-ops and never produce misleading logs',
    () async {
      await provider.updatePunch(now, -1);
      expect(storage.writes, 0);
      await provider.updatePunch(now, 1);
      await provider.updatePunch(now, -1);
      expect(provider.records, isEmpty);
      expect(provider.logs.length, 2);
    },
  );

  test('30 simultaneous edits preserve counts and all logs on disk', () async {
    await Future.wait(List.generate(30, (_) => provider.updatePunch(now, 1)));
    expect(provider.getCountForDate(now), 30);
    expect(storage.data.records.single.count, 30);
    expect(storage.data.logs.length, 30);
    expect(storage.data.logs.map((log) => log.id).toSet().length, 30);
  });

  test(
    'failed saves roll back visible state and do not poison later writes',
    () async {
      storage.failNextSave = true;
      await expectLater(provider.updatePunch(now, 1), throwsStateError);
      expect(provider.records, isEmpty);
      expect(provider.logs, isEmpty);
      expect(provider.isSaving, isFalse);
      await provider.updatePunch(now, 1);
      expect(provider.getCountForDate(now), 1);
      expect(provider.logs.length, 1);
    },
  );

  test(
    'settings validate, trim and save together with their audit log',
    () async {
      for (final interval in [0, -1, 366]) {
        await expectLater(
          provider.updateSettings('阅读', interval),
          throwsArgumentError,
        );
      }
      await expectLater(provider.updateSettings('   ', 1), throwsArgumentError);
      await provider.updateSettings('  阅读  ', 3);
      expect(storage.data.punchName, '阅读');
      expect(storage.data.idealIntervalDays, 3);
      expect(storage.data.logs.single.action, '设置更新');
      await provider.updateSettings('阅读', 3);
      expect(storage.writes, 1);
    },
  );

  test(
    'hiding and undoing a log persists without changing the count',
    () async {
      await provider.updatePunch(now, 1);
      final id = provider.logs.single.id;
      await provider.softDeleteLog(id);
      expect(storage.data.logs.single.isDeleted, isTrue);
      expect(provider.getCountForDate(now), 1);
      await provider.restoreLog(id);
      expect(storage.data.logs.single.isDeleted, isFalse);
    },
  );

  test(
    'ideal interval follows calendar days across DST and year boundaries',
    () async {
      now = DateTime(2026, 3, 8, 23);
      await provider.updatePunch(now, 1);
      expect(provider.getNextIdealDate(), DateTime(2026, 3, 9));
      now = DateTime(2026, 12, 31, 23);
      await provider.updatePunch(now, 1);
      expect(provider.getNextIdealDate(), DateTime(2027, 1, 1));
    },
  );

  test(
    'statistics follow their month and streak survives until today is done',
    () async {
      await provider.updatePunch(DateTime(2026, 9, 30), 4);
      await provider.updatePunch(DateTime(2026, 10, 16), 2);
      await provider.updatePunch(DateTime(2026, 10, 17), 1);
      expect(provider.monthTotal(now), 3);
      expect(provider.monthActiveDays(now), 2);
      expect(provider.monthTotal(DateTime(2026, 9)), 4);
      expect(provider.currentStreak, 2);
      await provider.updatePunch(now, 1);
      expect(provider.currentStreak, 3);
      now = DateTime(2026, 10, 20);
      expect(provider.currentStreak, 0);
    },
  );

  test(
    'duplicate legacy dates are consolidated without losing counts',
    () async {
      final other = PunchProvider(
        storageService: MemoryStorage(
          PunchData(
            records: [
              PunchRecord(date: DateTime.utc(2026, 10, 18), count: 2),
              PunchRecord(date: DateTime(2026, 10, 18, 16), count: 3),
            ],
          ),
        ),
        clock: () => now,
      );
      await other.ready;
      expect(other.getCountForDate(now), 5);
      expect(other.monthActiveDays(now), 1);
      expect(() => other.records.clear(), throwsUnsupportedError);
      other.dispose();
    },
  );

  test(
    'load failures end the spinner, block writes and allow a retry',
    () async {
      storage.failLoad = true;
      await provider.retryLoad();
      expect(provider.isLoading, isFalse);
      expect(provider.loadError, isNotNull);
      await expectLater(provider.updatePunch(now, 1), throwsStateError);
      expect(storage.writes, 0);
      storage.failLoad = false;
      await provider.retryLoad();
      expect(provider.loadError, isNull);
      await provider.updatePunch(now, 1);
      expect(storage.writes, 1);
    },
  );
}
