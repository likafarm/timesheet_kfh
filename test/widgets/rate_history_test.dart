// Экран ставок сотрудника: добавление, изменение, удаление; текущая ставка
// в списке сотрудников — из истории ставок.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/screens/employee_rate_history_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:provider/provider.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LocalDatabase db;
  late AppProvider app;
  late String emp;
  final today = calendarDay(DateTime.now());
  final start = DateTime(today.year - 1, 1, 1);

  Future<void> setUpApp(WidgetTester tester) async {
    await tester.runAsync(() async {
      db = LocalDatabase.memory();
      app = AppProvider(AppDatabase(db, ':memory:'));
      await app.addEmployee(
        Employee(
          fullName: 'Иванов Иван Иванович',
          position: 'Тракторист',
          hireDate: start,
          baseRate: 1000,
          fieldRate: 1500,
        ),
      );
      emp = app.employees.single.id!;
    });
    addTearDown(() => tester.runAsync(db.close));
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: MaterialApp(
          home: EmployeeRateHistoryScreen(
            employeeId: emp,
            employeeName: 'Иванов И. И.',
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  /// Дождаться записи в базу (drift — настоящая асинхронность).
  Future<void> settleDb(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }
  }

  testWidgets('текущая ставка — из истории', (tester) async {
    await setUpApp(tester);
    expect(app.currentRate(emp)?.baseRate, 1000);
    await open(tester);
    expect(find.text('Действует сегодня'), findsOneWidget);
    expect(find.textContaining('действует сейчас'), findsOneWidget);
  });

  testWidgets('добавить ставку с сегодняшнего дня, изменить, удалить', (
    tester,
  ) async {
    await setUpApp(tester);
    await open(tester);

    // Добавление: дата по умолчанию — сегодня.
    await tester.tap(find.text('Добавить ставку'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'База, ₽/день'),
      '2000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Поле, ₽/день'),
      '2500',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
    await settleDb(tester);

    var history = await tester.runAsync(
      () => DriftRepositories(db).rates.history(emp),
    );
    expect(history!.map((r) => r.baseRate), [1000, 2000]);
    expect(history.first.endDate, addCalendarDays(today, -1));
    expect(app.currentRate(emp)?.baseRate, 2000);
    // Копия в карточке сотрудника следует за текущей ставкой.
    expect(app.getEmployeeById(emp)?.baseRate, 2000);

    // Изменение сумм новой ставки.
    await tester.tap(find.textContaining('₽ · поле 2'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'База, ₽/день'),
      '2100',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await settleDb(tester);
    expect(app.currentRate(emp)?.baseRate, 2100);

    // Удаление новой — период возвращается к прежней.
    await tester.tap(find.byTooltip('Действия').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('перейдёт к предыдущей'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await settleDb(tester);
    history = await tester.runAsync(
      () => DriftRepositories(db).rates.history(emp),
    );
    expect(history!.single.endDate, isNull);
    expect(app.currentRate(emp)?.baseRate, 1000);
    expect(app.getEmployeeById(emp)?.baseRate, 1000);
  });

  testWidgets('та же дата начала — отказ с объяснением', (tester) async {
    await setUpApp(tester);
    final problem = await tester.runAsync(
      () => app.addRate(
        EmployeeRate(
          employeeId: emp,
          baseRate: 1,
          fieldRate: 1,
          startDate: start,
        ),
      ),
    );
    expect(problem, contains('уже есть'));
  });
}
