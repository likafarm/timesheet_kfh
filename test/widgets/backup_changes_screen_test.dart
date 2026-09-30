import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/screens/backup_changes_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:kfx_time_tracking/services/backup_service.dart';
import 'package:kfx_time_tracking/services/database_files.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

/// «Что изменилось с тех пор» и возврат записей из копии (3.7).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() => initializeDateFormatting('ru'));

  late Directory root;
  late AppDatabase appDb;
  late AppProvider app;
  late String ivan;
  late String petr;
  late DataSnapshot copy;

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<TimesheetRecord?> dayOf(
    WidgetTester tester,
    String emp,
    int m,
    int d,
  ) => tester
      .runAsync(() => appDb.repos.timesheet.on(emp, DateTime(2026, m, d)))
      .then((r) => r);

  /// Иванов: 20.08 (август потом закрыт), 01–03.09 — поле. После копии:
  /// 20.08 и 02.09 — база, 03.09 удалён, 04.09 добавлен; новый сотрудник
  /// Петров с днём 05.09.
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('kfh_changes_screen');
      appDb = await openAppDatabaseFile(p.join(root.path, 'v2.db'));
      final backups = BackupService(
        backupDirectory: p.join(root.path, 'backups'),
      );
      app = AppProvider(appDb, backupService: backups);
      final repos = appDb.repos;
      Employee employee(String name) => Employee(
        fullName: name,
        position: 'Рабочий',
        hireDate: DateTime(2025, 1, 1),
        baseRate: 1000,
        fieldRate: 1500,
      );
      Future<String> add(String emp, int m, int d, [String place = 'field']) =>
          repos.timesheet.add(
            TimesheetRecord(
              employeeId: emp,
              date: DateTime(2026, m, d),
              days: 1,
              workPlace: place,
            ),
          );
      ivan = await repos.employees.add(employee('Иванов Иван'));
      await add(ivan, 8, 20);
      for (final d in [1, 2, 3]) {
        await add(ivan, 9, d);
      }
      final path = await app.createBackup();
      copy = await backups.readSnapshot(path!);

      for (final d in [DateTime(2026, 8, 20), DateTime(2026, 9, 2)]) {
        final r = (await repos.timesheet.on(ivan, d))!;
        await repos.timesheet.update(r.copyWith(workPlace: 'base'));
      }
      await repos.timesheet.delete(
        (await repos.timesheet.on(ivan, DateTime(2026, 9, 3)))!.id!,
      );
      await add(ivan, 9, 4);
      petr = await repos.employees.add(employee('Петров Пётр'));
      await add(petr, 9, 5);
      await LocalSyncStore(appDb.db).saveLockedMonths([(2026, 8)]);
      await app.loadLockedMonths();
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        await app.closeDatabase();
        await root.delete(recursive: true);
      });
    });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: MaterialApp(
          home: BackupChangesScreen(
            title: 'Ежедневная',
            takenAt: DateTime(2026, 9, 30, 12),
            snapshot: copy,
          ),
        ),
      ),
    );
    await waitFor(tester, find.textContaining('Отличий'));
  }

  testWidgets('отличия и отбор по сотруднику и месяцу', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Отличий: 6'), findsOneWidget);
    expect(find.text('Место: в копии Поле → сейчас База'), findsNWidgets(2));
    expect(find.text('Табель: Иванов Иван · 03.09.2026'), findsOneWidget);
    expect(find.text('Удалено после копии'), findsOneWidget);
    expect(find.text('Добавлено после копии'), findsNWidgets(3));

    await tester.tap(find.text('Все сотрудники'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Петров Пётр').last);
    await tester.pumpAndSettle();
    expect(find.text('Отличий: 2 из 6'), findsOneWidget);
    expect(find.text('Сотрудник: Петров Пётр'), findsOneWidget);

    await tester.tap(find.text('Все месяцы'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Август 2026').last);
    await tester.pumpAndSettle();
    expect(find.text('По этому отбору отличий нет'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('вернуть выбранное: предпросмотр, копия до возврата', (
    tester,
  ) async {
    await pumpScreen(tester);
    final tile = find.ancestor(
      of: find.text('Табель: Иванов Иван · 02.09.2026'),
      matching: find.byType(CheckboxListTile),
    );
    await tester.tap(tile);
    await tester.pump();
    await tester.tap(find.text('Вернуть выбранные (1)…'));
    await tester.pumpAndSettle();
    expect(find.text('Вернуть выбранные записи?'), findsOneWidget);
    expect(
      find.textContaining('Будет возвращено как в копии', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Вернуть'));
    await waitFor(tester, find.textContaining('Возвращено записей: 1'));
    expect(find.textContaining('Возвращено записей: 1'), findsOneWidget);
    expect((await dayOf(tester, ivan, 9, 2))!.workPlace, 'field');
    await waitFor(tester, find.text('Отличий: 5'));
    expect(find.text('Отличий: 5'), findsOneWidget);

    final names = await tester.runAsync(
      () async => Directory(
        p.join(root.path, 'backups'),
      ).listSync().map((f) => p.basename(f.path)).toList(),
    );
    expect(
      names!.where((n) => n.startsWith('backup_before_rollback_')),
      hasLength(1),
    );
    // Возврат — обычная правка: уйдёт на сервер при синхронизации.
    final pending = await tester.runAsync(
      () => LocalSyncStore(appDb.db).pendingChanges(),
    );
    expect(pending!.map((c) => c.change.table), contains('timesheet'));
  });

  testWidgets('вся база на дату: закрытый месяц не тронут', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Вернуть всю базу на дату копии…'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Вернуть всю базу на 30.09.2026'),
      findsOneWidget,
    );
    expect(find.text('Не будет тронуто: 1'), findsOneWidget);
    expect(find.textContaining('08.2026 закрыт'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Вернуть'));
    await waitFor(tester, find.text('Отличий: 1'));
    expect(find.text('Отличий: 1'), findsOneWidget);

    expect(await dayOf(tester, ivan, 9, 3), isNotNull);
    expect(await dayOf(tester, ivan, 9, 4), isNull);
    expect(await dayOf(tester, petr, 9, 5), isNull);
    expect((await dayOf(tester, ivan, 8, 20))!.workPlace, 'base');
    expect(tester.takeException(), isNull);
  });
}
