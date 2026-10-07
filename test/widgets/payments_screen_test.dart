import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/screens/payments_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Выплаты на компьютере (решение владельца 2026-10-06): тип и способ —
/// кнопками, сотрудник одной выплаты — из фильтра; таблица — как
/// «Сотрудники» (№, долгое нажатие — правка).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() => initializeDateFormatting('ru'));

  late LocalDatabase db;
  late DriftRepositories repos;
  late AppProvider app;
  final ids = <String>[];

  Future<void> setUpData(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      db = LocalDatabase.memory();
      repos = DriftRepositories(db);
      app = AppProvider(AppDatabase(db, ':memory:'));
      ids.clear();
      for (final name in ['Иванов Иван Иванович', 'Петров Пётр Петрович']) {
        ids.add(
          await repos.employees.add(
            Employee(
              fullName: name,
              position: 'Рабочий',
              hireDate: DateTime(2025, 3, 1),
              baseRate: 2000,
              fieldRate: 2500,
            ),
          ),
        );
      }
      await app.loadAllData();
    });
    addTearDown(() async {
      app.dispose();
      await tester.runAsync(db.close);
    });
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<List<Payment>> saved(WidgetTester tester) async =>
      (await tester.runAsync(() => repos.payments.list()))!;

  testWidgets('одна выплата: сотрудник из фильтра, тип и способ — кнопками; '
      'строка таблицы с № открывается долгим нажатием', (tester) async {
    await setUpData(tester);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(home: PaymentsScreen()),
      ),
    );
    await settle(tester);

    // Фильтр «Сотрудник» — Петров.
    await tester.tap(find.byType(DropdownButton<String?>));
    await settle(tester);
    await tester.tap(find.text('Петров П. П.').last);
    await settle(tester);
    await tester.tap(find.byTooltip('Добавить выплату'));
    await settle(tester);

    expect(find.text('Новая выплата'), findsOneWidget);
    expect(find.text('Сотрудник *'), findsNothing);
    expect(find.text('Петров Пётр Петрович'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsNothing);
    // По умолчанию — зарплата, способ не указан.
    expect(find.widgetWithText(FilledButton, 'Зарплата'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Не указано'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Аванс'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Наличные'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Сумма (₽) *'),
      '5000',
    );
    await settle(tester);
    expect(find.widgetWithText(FilledButton, 'Аванс'), findsOneWidget);
    await tester.tap(find.text('Добавить'));
    await settle(tester);

    final list = await saved(tester);
    expect(list, hasLength(1));
    expect(list.single.employeeId, ids[1]);
    expect(list.single.amount, 5000);
    expect(list.single.paymentType, 'advance');
    expect(list.single.paymentMethod, 'cash');

    // Таблица: № и долгое нажатие — правка с выбранными кнопками.
    expect(find.text('№'), findsOneWidget);
    await tester.longPress(find.text('Петров Пётр Петрович'));
    await settle(tester);
    expect(find.text('Редактирование выплаты'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Аванс'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Наличные'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('групповая выплата: тип и способ — кнопками', (tester) async {
    await setUpData(tester);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(home: PaymentsScreen()),
      ),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('Групповая выплата'));
    await settle(tester);
    expect(find.text('Групповая выплата'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Зарплата'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Премия'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'На карту'));
    await settle(tester);
    expect(find.widgetWithText(FilledButton, 'Премия'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'На карту'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Зарплата'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
