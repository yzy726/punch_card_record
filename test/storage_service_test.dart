import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:punch_card_record/models/punch_data.dart';
import 'package:punch_card_record/models/punch_record.dart';
import 'package:punch_card_record/models/punch_workspace.dart';
import 'package:punch_card_record/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('punch_card_test_');
    storage = StorageService(directory: directory);
  });

  tearDown(() async => directory.delete(recursive: true));

  PunchWorkspace snapshot(int count) => PunchWorkspace.single(PunchData(
    records: [PunchRecord(date: DateTime(2026, 10, 18), count: count)],
  ));

  test(
    'migrates old files and preferences without deleting originals',
    () async {
      SharedPreferences.setMockInitialValues({
        'punchName': '阅读',
        'idealIntervalDays': -2,
      });
      final original = File('${directory.path}/punch_records.json');
      await original.writeAsString(
        jsonEncode([
          {'date': '2026-10-18T00:00:00.000Z', 'count': 2},
          {'date': '2026-10-18T08:00:00.000', 'count': 1},
        ]),
      );
      final loaded = await storage.load();
      final data = loaded.active.data;
      expect(data.punchName, '阅读');
      expect(data.idealIntervalDays, 1);
      expect(data.records.single.count, 3);
      await storage.save(loaded);
      expect(await original.exists(), isTrue);
      expect(
        (await StorageService(
          directory: directory,
        ).load()).active.data.records.single.count,
        3,
      );
    },
  );

  test('round trips a complete snapshot and keeps a previous backup', () async {
    await storage.load();
    await storage.save(snapshot(1));
    await storage.save(snapshot(2));
    expect((await storage.load()).active.data.records.single.count, 2);
    final backup =
        jsonDecode(
              await File(
                '${directory.path}/punch_data.json.bak',
              ).readAsString(),
            )
            as Map<String, dynamic>;
    expect(PunchWorkspace.fromJson(backup).active.data.records.single.count, 1);
  });

  test(
    'recovers corruption and keeps the healthy backup on the next save',
    () async {
      await storage.load();
      await storage.save(snapshot(1));
      await storage.save(snapshot(2));
      await File('${directory.path}/punch_data.json').writeAsString('{broken');
      final recovered = StorageService(directory: directory);
      expect((await recovered.load()).active.data.records.single.count, 1);
      expect(recovered.recoveryMessage, isNotNull);
      await recovered.save(snapshot(3));
      final backup =
          jsonDecode(
                await File(
                  '${directory.path}/punch_data.json.bak',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(PunchWorkspace.fromJson(backup).active.data.records.single.count, 1);
      expect(
        (await StorageService(
          directory: directory,
        ).load()).active.data.records.single.count,
        3,
      );
    },
  );

  test(
    'corrupt legacy data is reported instead of silently becoming empty',
    () async {
      final original = File('${directory.path}/punch_records.json');
      await original.writeAsString('{broken');
      await expectLater(storage.load(), throwsFormatException);
      expect(await original.readAsString(), '{broken');
      expect(await File('${directory.path}/punch_data.json').exists(), isFalse);
    },
  );

  test(
    'a corrupt primary and backup both remain intact for recovery',
    () async {
      final primary = File('${directory.path}/punch_data.json');
      final backup = File('${primary.path}.bak');
      await primary.writeAsString('broken primary');
      await backup.writeAsString('broken backup');
      await expectLater(storage.load(), throwsA(isA<FileSystemException>()));
      expect(await primary.readAsString(), 'broken primary');
      expect(await backup.readAsString(), 'broken backup');
    },
  );
}
