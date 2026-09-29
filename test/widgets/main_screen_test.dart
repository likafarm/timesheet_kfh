import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/providers/sync_provider.dart';
import 'package:kfx_time_tracking/screens/employee_rate_history_screen.dart';
import 'package:kfx_time_tracking/screens/main_screen.dart';
import 'package:kfx_time_tracking/screens/periods_screen.dart';
import 'package:kfx_time_tracking/screens/sync_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../support/sync_test_server.dart';

/// Каркас (шаг 4.3): телефон — нижняя навигация, широкий экран — боковая
/// панель; оператору — только табель, сотрудники и сервер.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUpAll(() => initializeDateFormatting('ru'));
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'kfh',
      packageName: 'kfh',
      version: '1.3.0',
      buildNumber: '5',
      buildSignature: '',
    ),
  );

  Future<void> pumpMain(
    WidgetTester tester, {
    required Size size,
    required bool operator,
    bool phone = false,
    Future<void> Function(LocalDatabase db)? seed,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late LocalDatabase db;
    late AppProvider app;
    late SyncProvider sync;
    await tester.runAsync(() async {
      db = LocalDatabase.memory();
      await seed?.call(db);
      app = AppProvider(AppDatabase(db, ':memory:'), operatorMode: operator);
      await app.loadAllData();
      sync = SyncProvider(
        appVersion: () async => '1.3.0',
        database: db,
        onDataChanged: () async {},
        backup: () async {},
        tokenStore: (_) => MemoryTokenStore(),
        httpClient: () => MockClient(SyncTestServer().handle),
        journal: MemorySyncJournal(),
        autoSync: false,
        debugBuild: false,
        client: operator || phone ? ClientKind.phone : ClientKind.desktop,
      );
      await sync.init();
    });
    addTearDown(() async {
      sync.dispose();
      app.dispose();
      await tester.runAsync(db.close);
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: app),
          ChangeNotifierProvider.value(value: sync),
        ],
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  testWidgets('оператор на телефоне: нижняя навигация, четыре раздела', (
    tester,
  ) async {
    await pumpMain(tester, size: const Size(390, 844), operator: true);
    final bar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(bar.items.map((i) => i.label), [
      'День',
      'Табель',
      'Сотрудники',
      'Сервер',
    ]);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Выплаты'), findsNothing);
    final ex = tester.takeException();
    if (ex is FlutterError) debugPrint(ex.toStringDeep());
    expect(ex, isNull);
  });

  testWidgets('Windows 1024×768: боковая панель, все разделы', (tester) async {
    await pumpMain(tester, size: const Size(1024, 768), operator: false);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations, hasLength(6));
    // Первый раздел — сводка (6.8).
    expect(rail.selectedIndex, 0);
    expect(find.text('Долг по зарплате на сегодня'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);

    await tester.tap(find.text('Сотрудники'));
    await tester.pump();
    expect(rail.destinations, hasLength(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('бухгалтер на телефоне (6.9): внизу четыре раздела и «Ещё», '
      'все разделы без ошибок раскладки', (tester) async {
    await pumpMain(
      tester,
      size: const Size(360, 740),
      operator: false,
      phone: true,
      seed: (db) async {
        final repos = DriftRepositories(db);
        final now = DateTime.now();
        final id = await repos.employees.add(
          Employee(
            fullName: 'Константинопольский Константин Константинович',
            position: 'Механизатор',
            hireDate: DateTime(2025, 1, 1),
            baseRate: 1000,
            fieldRate: 1500,
          ),
        );
        await repos.rates.add(
          EmployeeRate(
            employeeId: id,
            baseRate: 1000,
            fieldRate: 1500,
            startDate: DateTime(2025, 1, 1),
          ),
        );
        await repos.timesheet.add(
          TimesheetRecord(
            employeeId: id,
            date: DateTime(now.year, now.month, 1),
            days: 1,
            workPlace: 'field',
          ),
        );
        await repos.payments.add(
          Payment(
            employeeId: id,
            paymentDate: DateTime(now.year, now.month, 1),
            amount: 123456.78,
          ),
        );
      },
    );
    final bar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(bar.items.map((i) => i.label), [
      'Главная',
      'Табель',
      'Выплаты',
      'Отчёты',
      'Ещё',
    ]);

    Future<void> settle() async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    Future<void> check(String section) async {
      final ex = tester.takeException();
      if (ex != null) {
        // Какая строка переполнена — в выводе теста.
        for (final r in tester.allRenderObjects.whereType<RenderFlex>()) {
          if (r.direction != Axis.horizontal || !r.hasSize) continue;
          var w = 0.0;
          r.visitChildren((c) => w += (c as RenderBox).size.width);
          if (w > r.size.width + 1) {
            debugPrint('$section: переполнена ${r.debugCreator}');
          }
        }
      }
      expect(ex, isNull, reason: section);
    }

    await settle();
    await check('Главная');
    for (final label in ['Табель', 'Выплаты', 'Отчёты']) {
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text(label),
        ),
      );
      await settle();
      await check(label);
    }
    for (final label in ['Сотрудники', 'Настройки']) {
      await tester.tap(find.text('Ещё'));
      await settle();
      await tester.tap(find.widgetWithText(ListTile, label));
      await settle();
      await check(label);
    }
    // Вложенные экраны и окна — тоже без ошибок раскладки.
    final nav = Navigator.of(tester.element(find.byType(MainScreen)));
    final app = tester.element(find.byType(MainScreen)).read<AppProvider>();
    final employee = app.employees.first;
    final screens = <String, Widget>{
      'Ставки': EmployeeRateHistoryScreen(
        employeeId: employee.id!,
        employeeName: employee.fullName,
      ),
      'Закрытие месяцев': const PeriodsScreen(),
      'Сервер синхронизации': const SyncScreen(),
    };
    for (final MapEntry(key: name, value: screen) in screens.entries) {
      unawaited(nav.push(MaterialPageRoute<void>(builder: (_) => screen)));
      await settle();
      await check(name);
      nav.pop();
      await settle();
    }

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Выплаты'),
      ),
    );
    await settle();
    await tester.tap(find.byTooltip('Групповая выплата'));
    await settle();
    expect(find.text('Групповая выплата'), findsWidgets);
    await check('Групповая выплата');
  });
}
