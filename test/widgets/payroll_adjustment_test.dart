import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:kfx_time_tracking/widgets/payroll_detail_dialog.dart';
import 'package:provider/provider.dart';

/// Корректировка начисления в подробном расчёте сотрудника.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LocalDatabase db;
  late AppProvider app;
  late Employee employee;

  Future<void> setUpApp(WidgetTester tester) async {
    await tester.runAsync(() async {
      await initializeDateFormatting('ru');
      db = LocalDatabase.memory();
      app = AppProvider(AppDatabase(db, ':memory:'), operatorMode: false);
      final repos = DriftRepositories(db);
      final id = await repos.employees.add(
        Employee(
          fullName: 'Иванов Иван',
          position: 'Механизатор',
          hireDate: DateTime(2026, 1, 1),
          baseRate: 2000,
          fieldRate: 3000,
        ),
      );
      employee = (await repos.employees.byId(id))!;
    });
    addTearDown(() => tester.runAsync(db.close));
  }

  /// Текст суммы: в русском формате тысячи разделяет неразрывный пробел.
  Finder amount(String text) => find.byWidgetPredicate(
    (w) =>
        w is Text &&
        w.data
                ?.replaceAll(String.fromCharCode(0xA0), ' ')
                .replaceAll(String.fromCharCode(0x202F), ' ') ==
            text,
  );

  /// Шаг с базой: действие, затем время на запросы drift и перерисовка.
  Future<void> step(WidgetTester tester, Future<void> Function() action) async {
    await tester.runAsync(() async {
      await action();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('добавить, изменить и удалить корректировку', (tester) async {
    await setUpApp(tester);
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: MaterialApp(
          home: Scaffold(
            body: PayrollDetailDialog(
              employee: employee,
              result: PayrollResult(
                employeeId: employee.id!,
                year: 2026,
                month: 9,
                baseDays: 0,
                fieldDays: 0,
                sickDays: 0,
                vacationDays: 0,
                totalSalary: 0,
              ),
              payments: const [],
              startingBalance: 0,
            ),
          ),
        ),
      ),
    );
    await step(tester, () async {});

    await tester.tap(find.text('Корректировка'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Сумма, ₽'),
      '13 000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Примечание'),
      'надбавка',
    );
    await step(tester, () async {
      await tester.tap(find.text('Сохранить'));
      await tester.pump();
    });
    expect(find.text('Корректировка: надбавка'), findsOneWidget);
    expect(amount('13 000,00'), findsNWidgets(2), reason: 'и в «ИТОГО»');
    final saved = await tester.runAsync(
      () => DriftRepositories(db).adjustments.all(),
    );
    expect(saved!.single.amount, 13000);

    // Удержание вместо доплаты.
    await tester.tap(find.text('Корректировка: надбавка'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Сумма, ₽'), '-500');
    await step(tester, () async {
      await tester.tap(find.text('Сохранить'));
      await tester.pump();
    });
    expect(amount('-500,00'), findsNWidgets(2));

    await tester.tap(find.text('Корректировка: надбавка'));
    await tester.pumpAndSettle();
    await step(tester, () async {
      await tester.tap(find.text('Удалить'));
      await tester.pump();
    });
    expect(find.textContaining('Корректировка:'), findsNothing);
    final left = await tester.runAsync(
      () => DriftRepositories(db).adjustments.all(),
    );
    expect(left, isEmpty);
  });
}
