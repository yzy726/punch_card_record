import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:punch_card_record/main.dart';
import 'package:punch_card_record/models/punch_backup.dart';
import 'package:punch_card_record/models/punch_data.dart';
import 'package:punch_card_record/models/punch_record.dart';
import 'package:punch_card_record/providers/punch_provider.dart';
import 'package:punch_card_record/screens/backup_page.dart';
import 'package:punch_card_record/screens/punch_sheet.dart';
import 'package:punch_card_record/services/backup_file_service.dart';
import 'package:provider/provider.dart';

import 'test_support.dart';

class TestBackupFiles extends BackupFileService {
  PunchBackup? selected;
  String? exported;

  @override
  Future<bool> exportFile(String contents, String filename) async {
    exported = contents;
    return true;
  }

  @override
  Future<PunchBackup?> pickBackup() async => selected;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
    final font = File('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc');
    if (await font.exists()) {
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  final now = DateTime(2026, 10, 18, 0, 5);

  Future<PunchProvider> home(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    MemoryStorage? storage,
    DateTime Function()? clock,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = PunchProvider(
      storageService: storage ?? MemoryStorage(),
      clock: clock ?? () => now,
    );
    await provider.ready;
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('preview'),
        child: MyApp(provider: provider),
      ),
    );
    await tester.pumpAndSettle();
    return provider;
  }

  Future<void> snapshot(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/previews/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('today calendar cell opens and can be punched before 08:00', (
    tester,
  ) async {
    final provider = await home(tester);
    final semantics = tester.ensureSemantics();
    final day = find.byKey(const ValueKey('calendar-2026-10-18'));
    await tester.ensureVisible(day);
    await tester.tap(day);
    await tester.pumpAndSettle();
    expect(find.byType(PunchSheet), findsOneWidget);
    final decrement = tester.widget<OutlinedButton>(
      find.byKey(const Key('decrementPunch')),
    );
    expect(decrement.onPressed, isNull);
    await tester.tap(find.byKey(const Key('incrementPunch')));
    await tester.pumpAndSettle();
    expect(provider.getCountForDate(now), 1);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('future calendar cells explain why they cannot be punched', (
    tester,
  ) async {
    final provider = await home(tester);
    final semantics = tester.ensureSemantics();
    final day = find.byKey(const ValueKey('calendar-2026-10-19'));
    await tester.ensureVisible(day);
    await tester.tap(day);
    await tester.pumpAndSettle();
    expect(find.byType(PunchSheet), findsNothing);
    expect(find.text('不能提前打卡未来的日期'), findsOneWidget);
    expect(provider.records, isEmpty);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('quick punch and log hiding can be undone', (tester) async {
    final provider = await home(tester);
    await tester.tap(find.byKey(const Key('todayPunchButton')));
    await tester.pumpAndSettle();
    expect(provider.getCountForDate(now), 1);
    await tester.tap(find.byTooltip('打卡日志'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('隐藏日志'));
    await tester.pumpAndSettle();
    expect(provider.logs.single.isDeleted, isTrue);
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(provider.logs.single.isDeleted, isFalse);
    expect(provider.getCountForDate(now), 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('settings reject empty names and zero intervals', (tester) async {
    final provider = await home(tester);
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('punchNameField')), '  ');
    await tester.enterText(find.byKey(const Key('intervalField')), '0');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('请输入打卡名称'), findsOneWidget);
    expect(find.text('请输入 1–365 之间的整数'), findsOneWidget);
    expect(provider.punchName, '每日打卡');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('small screens scroll without overflows', (tester) async {
    await home(tester, size: const Size(320, 568));
    await tester.drag(
      find.byKey(const Key('homeScroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('数据保存在本机 · 每一次记录都算数'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('resuming after midnight refreshes today without restarting', (
    tester,
  ) async {
    var clock = DateTime(2026, 10, 18, 23, 59);
    final storage = MemoryStorage(
      PunchData(records: [PunchRecord(date: clock, count: 1)]),
    );
    final provider = await home(tester, storage: storage, clock: () => clock);
    expect(find.text('再打卡一次'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    clock = DateTime(2026, 10, 19, 0, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(provider.today, DateTime(2026, 10, 19));
    expect(find.text('今日打卡'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'backup export, preview cancellation and merge use real provider data',
    (tester) async {
      final provider = PunchProvider(
        storageService: MemoryStorage(),
        clock: () => now,
      );
      await provider.ready;
      addTearDown(provider.dispose);
      await provider.updatePunch(now, 2);
      final files = TestBackupFiles()
        ..selected = PunchBackup(
          exportedAt: now,
          data: PunchData(records: [PunchRecord(date: now, count: 5)]),
        );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(home: BackupPage(files: files)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('exportDataButton')));
      await tester.pumpAndSettle();
      expect(PunchBackup.decode(files.exported!).data.records.single.count, 2);
      await tester.tap(find.byKey(const Key('importDataButton')));
      await tester.pumpAndSettle();
      expect(find.text('预览导入数据'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(provider.getCountForDate(now), 2);
      await tester.tap(find.byKey(const Key('importDataButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认导入'));
      await tester.pumpAndSettle();
      expect(provider.getCountForDate(now), 5);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('render home, transfer and log previews', (tester) async {
    final storage = MemoryStorage(
      PunchData(
        punchName: '每天，进步一点点',
        records: [
          for (final day in [2, 4, 6, 9, 12, 13, 14, 15, 16, 17, 18])
            PunchRecord(
              date: DateTime(2026, 10, day),
              count: day == 18 ? 2 : 1,
            ),
        ],
      ),
    );
    final provider = await home(
      tester,
      size: const Size(390, 1100),
      storage: storage,
    );
    await provider.updatePunch(now, 1);
    await tester.pumpAndSettle();
    await snapshot(tester, 'home');
    await tester.tap(find.byKey(const Key('backupButton')));
    await tester.pumpAndSettle();
    await snapshot(tester, 'backup');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打卡日志'));
    await tester.pumpAndSettle();
    await snapshot(tester, 'logs');
    await tester.pumpWidget(const SizedBox());
  });
}
