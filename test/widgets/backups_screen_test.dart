import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/providers/sync_provider.dart';
import 'package:kfx_time_tracking/screens/backup_view_screen.dart';
import 'package:kfx_time_tracking/screens/backups_screen.dart';
import 'package:kfx_time_tracking/services/backup_service.dart';
import 'package:kfx_time_tracking/services/database_files.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../support/sync_test_server.dart';

/// Модуль «Резервные копии» (3.5): копии этого компьютера и сервера.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const serverName = 'kfh-20260930-003000.json.gz.age';
  const keyPath = 'packages/sync/test/fixtures/age/key.txt';

  late Directory root;
  late AppProvider app;
  late SyncProvider sync;
  late SyncTestServer server;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Дождаться [finder]: база, изолят и расшифровка идут вне поддельного
  /// времени теста.
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    String role = 'admin',
    String key = keyPath,
  }) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    server = SyncTestServer()..role = role;
    server.backupFiles[serverName] = File(
      'test/fixtures/server_snapshot.json.gz.age',
    ).readAsBytesSync();
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('kfh_backups_screen');
      final appDb = await openAppDatabaseFile(p.join(root.path, 'v2.db'));
      app = AppProvider(
        appDb,
        backupService: BackupService(
          backupDirectory: p.join(root.path, 'backups'),
        ),
      );
      sync = SyncProvider(
        database: appDb.db,
        onDataChanged: () async {},
        backup: () async {},
        tokenStore: (_) => MemoryTokenStore(),
        httpClient: () => MockClient(server.handle),
        journal: MemorySyncJournal(),
        autoSync: false,
        debugBuild: false,
        client: ClientKind.desktop,
        appVersion: () async => '1.14.0',
      );
      await sync.init();
      await sync.signIn('localhost', 'ivan', 'secret-pass');
      await sync.link(await sync.analyzeLink());
      final repos = appDb.repos;
      final ivan = await repos.employees.add(
        Employee(
          fullName: 'Иванов Иван',
          position: 'Рабочий',
          hireDate: DateTime(2025, 1, 1),
          baseRate: 1000,
          fieldRate: 1500,
        ),
      );
      for (final d in [1, 2]) {
        await repos.timesheet.add(
          TimesheetRecord(
            employeeId: ivan,
            date: DateTime(2026, 9, d),
            days: 1,
            workPlace: 'field',
          ),
        );
      }
      await app.createBackup();
    });
    addTearDown(() async {
      sync.dispose();
      await tester.runAsync(() async {
        await app.closeDatabase();
        await root.delete(recursive: true);
      });
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: app),
          ChangeNotifierProvider.value(value: sync),
        ],
        child: MaterialApp(home: BackupsScreen(keyPath: key)),
      ),
    );
    await settle(tester);
  }

  /// Число в строке таблицы открытой копии.
  int countOf(WidgetTester tester, String label) {
    final tile = find.ancestor(
      of: find.text(label),
      matching: find.byType(ListTile),
    );
    final value = find.descendant(of: tile, matching: find.byType(Text)).last;
    return int.parse(tester.widget<Text>(value).data!);
  }

  testWidgets('копии этого компьютера и сервера открываются', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Ежедневная'), findsOneWidget);
    expect(find.text('Копия сервера'), findsOneWidget);

    await tester.tap(find.text('Открыть').first);
    await waitFor(tester, find.byType(BackupViewScreen));
    expect(find.byType(BackupViewScreen), findsOneWidget);
    expect(countOf(tester, 'Сотрудники'), 1);
    expect(countOf(tester, 'Дни табеля'), 2);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await settle(tester);

    await tester.tap(find.text('Открыть').last);
    await waitFor(tester, find.textContaining('Копия сервера на '));
    expect(find.textContaining('Копия сервера на '), findsOneWidget);
    expect(countOf(tester, 'Дни табеля'), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('создать и удалить копию', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Создать копию'));
    await waitFor(tester, find.text('Копия создана'));
    expect(find.text('Копия создана'), findsOneWidget);

    await tester.tap(find.byTooltip('Удалить копию').first);
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await settle(tester);
    expect(find.text('Копий на этом компьютере пока нет'), findsOneWidget);
  });

  testWidgets('нет ключа — просьба выбрать файл, копия не открывается', (
    tester,
  ) async {
    await pumpScreen(tester, key: p.join('нет', 'ключа.key'));
    await tester.tap(find.text('Открыть').last);
    await settle(tester);
    expect(find.text('Нужен ключ копий'), findsOneWidget);
    expect(find.textContaining('Нет файла ключа'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await settle(tester);
    expect(find.byType(BackupViewScreen), findsNothing);
  });

  testWidgets('копии сервера — только админу', (tester) async {
    await pumpScreen(tester, role: 'accountant');
    expect(find.text('Нужен вход администратора на сервер'), findsOneWidget);
    expect(find.text('Копия сервера'), findsNothing);
  });

  testWidgets('как устроены копии', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('Как устроены копии'));
    await settle(tester);
    expect(find.textContaining('03:30 по Москве'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
