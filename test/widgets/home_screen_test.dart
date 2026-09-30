import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/providers/sync_provider.dart';
import 'package:kfx_time_tracking/screens/home_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:kfx_time_tracking/widgets/payroll_detail_dialog.dart';
import 'package:kfx_time_tracking/widgets/section_navigation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../support/sync_test_server.dart';

/// Главный экран-сводка (6.8).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final today = DateTime(2026, 9, 29);
  final money = NumberFormat('#,##0.00', 'ru');

  setUpAll(() => initializeDateFormatting('ru'));
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'kfh',
      packageName: 'kfh',
      version: '1.10.0',
      buildNumber: '1',
      buildSignature: '',
    ),
  );

  /// Сотрудник «Иванов» со ставкой 1000 работал на базе все рабочие дни
  /// 1–24 сентября, получил 5000; «Петров» без ставки работал 28-го, а
  /// 2 июня 2025 г. у него рабочий день без места (старая ошибка ввода).
  Future<int> seed(LocalDatabase db) async {
    final repos = DriftRepositories(db);
    Employee emp(String name) => Employee(
      fullName: name,
      position: 'Рабочий',
      hireDate: DateTime(2026, 1, 1),
      baseRate: 0,
      fieldRate: 0,
    );
    final ivanov = await repos.employees.add(emp('Иванов'));
    final petrov = await repos.employees.add(emp('Петров'));
    await repos.rates.add(
      EmployeeRate(
        employeeId: ivanov,
        baseRate: 1000,
        fieldRate: 1500,
        startDate: DateTime(2026, 1, 1),
      ),
    );
    var days = 0;
    for (var d = 1; d <= 24; d++) {
      final day = DateTime(2026, 9, d);
      if (!ProductionCalendar.isWorkingDay(day)) continue;
      days++;
      await repos.timesheet.add(
        TimesheetRecord(
          employeeId: ivanov,
          date: day,
          days: 1,
          workPlace: 'base',
        ),
      );
    }
    await repos.timesheet.add(
      TimesheetRecord(
        employeeId: petrov,
        date: DateTime(2026, 9, 28),
        days: 1,
        workPlace: 'base',
      ),
    );
    await repos.timesheet.add(
      TimesheetRecord(employeeId: petrov, date: DateTime(2025, 6, 2), days: 1),
    );
    await repos.payments.add(
      Payment(
        employeeId: ivanov,
        paymentDate: DateTime(2026, 9, 10),
        amount: 5000,
      ),
    );
    return days;
  }

  Future<SectionNavigator> pumpHome(
    WidgetTester tester, {
    required Size size,
    bool withData = true,
    void Function(int workdays)? onSeeded,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late LocalDatabase db;
    late AppProvider app;
    late SyncProvider sync;
    await tester.runAsync(() async {
      db = LocalDatabase.memory();
      if (withData) onSeeded?.call(await seed(db));
      app = AppProvider(AppDatabase(db, ':memory:'));
      await app.loadAllData();
      sync = SyncProvider(
        appVersion: () async => '1.10.0',
        database: db,
        onDataChanged: () async {},
        backup: () async {},
        tokenStore: (_) => MemoryTokenStore(),
        httpClient: () => MockClient(SyncTestServer().handle),
        journal: MemorySyncJournal(),
        autoSync: false,
        debugBuild: false,
        client: ClientKind.desktop,
      );
      await sync.init();
    });
    final navigator = SectionNavigator();
    addTearDown(() async {
      navigator.dispose();
      sync.dispose();
      app.dispose();
      await tester.runAsync(db.close);
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: app),
          ChangeNotifierProvider.value(value: sync),
          ChangeNotifierProvider.value(value: navigator),
        ],
        child: MaterialApp(home: HomeScreen(today: today)),
      ),
    );
    await settle(tester);
    return navigator;
  }

  testWidgets('долг, напоминания и переход в табель', (tester) async {
    var workdays = 0;
    final navigator = await pumpHome(
      tester,
      size: const Size(1280, 900),
      onSeeded: (d) => workdays = d,
    );
    final debt = workdays * 1000.0 - 5000;
    expect(find.text('${money.format(debt)} ₽'), findsWidgets);
    expect(find.textContaining('Табель не внесён'), findsOneWidget);
    expect(find.text('Петров: 1 раб. дн. без ставки'), findsOneWidget);
    expect(find.text('Норма по календарю'), findsOneWidget);
    expect(find.text('Закрытых месяцев нет'), findsOneWidget);

    await tester.tap(find.textContaining('Табель не внесён'));
    await tester.pump();
    expect(navigator.takeSection(), AppSection.timesheet);
    expect(navigator.takeMonth(AppSection.timesheet), DateTime(2026, 9));

    expect(find.textContaining('Петров 02.06.2025'), findsOneWidget);
    await tester.tap(find.text('Дни без места работы: 1'));
    await tester.pump();
    expect(navigator.takeSection(), AppSection.timesheet);
    expect(navigator.takeMonth(AppSection.timesheet), DateTime(2025, 6));

    await tester.tap(find.text('Иванов'));
    await settle(tester);
    expect(find.byType(PayrollDetailDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('телефон, пустая база: «Всё в порядке», без ошибок раскладки', (
    tester,
  ) async {
    await pumpHome(tester, size: const Size(390, 844), withData: false);
    expect(find.text('Всё в порядке'), findsOneWidget);
    expect(find.text('Долгов нет'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('напоминание о синхронизации', () {
    final now = DateTime(2026, 9, 29, 12);
    String? reminder({
      SyncPhase phase = SyncPhase.ready,
      bool linked = true,
      int pending = 0,
      int rejected = 0,
      bool troubled = false,
      DateTime? lastSyncAt,
    }) => syncReminder(
      phase: phase,
      linked: linked,
      pending: pending,
      rejected: rejected,
      troubled: troubled,
      lastSyncAt: lastSyncAt ?? now.subtract(const Duration(minutes: 5)),
      now: now,
    );

    test('всё хорошо — нет напоминания', () {
      expect(reminder(), isNull);
      // Правки уходят сами — пока нет сбоя, не напоминаем.
      expect(reminder(pending: 3), isNull);
      // Программа без сервера — не напоминаем.
      expect(reminder(phase: SyncPhase.signedOut, linked: false), isNull);
    });

    test('отказы, неотправленное при сбое, давняя синхронизация, выход', () {
      expect(reminder(rejected: 2, pending: 2), 'Не принято сервером: 2');
      expect(
        reminder(pending: 3, rejected: 1, troubled: true),
        'Не принято сервером: 1, не отправлено: 2',
      );
      expect(
        reminder(lastSyncAt: DateTime(2026, 9, 27, 9, 15)),
        'Последняя синхронизация 27.09.2026 в 09:15',
      );
      expect(
        reminder(phase: SyncPhase.signedOut),
        'Вход на сервер не выполнен — правки не уходят на сервер',
      );
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
}
