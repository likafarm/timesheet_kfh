import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/screens/employees_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:kfx_time_tracking/widgets/employee_form_dialog.dart';
import 'package:provider/provider.dart';

/// Сотрудники на телефоне (6.10): карточка — долгим нажатием и на весь
/// экран, увольнение — панелью снизу, как окно выплаты.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() => initializeDateFormatting('ru'));

  late LocalDatabase db;
  late DriftRepositories repos;
  late AppProvider app;
  late String id;

  Future<void> setUpData(WidgetTester tester, {required bool operator}) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      db = LocalDatabase.memory();
      repos = DriftRepositories(db);
      app = AppProvider(AppDatabase(db, ':memory:'), operatorMode: operator);
      id = await repos.employees.add(
        Employee(
          fullName: 'Иванов Иван Иванович',
          position: 'Рабочий',
          hireDate: DateTime(2025, 3, 1),
          baseRate: 0,
          fieldRate: 0,
        ),
      );
      await app.loadAllData();
    });
    addTearDown(() async {
      app.dispose();
      await tester.runAsync(db.close);
    });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(home: EmployeesScreen()),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  testWidgets('касание — подсказка, долгое нажатие — карточка на весь экран', (
    tester,
  ) async {
    await setUpData(tester, operator: false);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Иванов Иван Иванович'));
    await tester.pump();
    expect(
      find.text('Удерживайте строку, чтобы открыть карточку'),
      findsOneWidget,
    );
    expect(find.byType(EmployeeFormDialog), findsNothing);

    await tester.longPress(find.text('Иванов Иван Иванович'));
    await tester.pumpAndSettle();
    expect(find.byType(EmployeeFormDialog), findsOneWidget);
    // Страница, а не окно поверх списка.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Редактирование сотрудника'), findsOneWidget);
    expect(
      tester.getSize(find.byType(EmployeeFormDialog)),
      const Size(360, 740),
    );
    expect(find.widgetWithText(TextButton, 'Сохранить'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('оператор: карточка только для просмотра', (tester) async {
    await setUpData(tester, operator: true);
    await tester.longPress(find.text('Иванов Иван Иванович'));
    await tester.pumpAndSettle();
    expect(find.text('Сотрудник'), findsOneWidget);
    expect(find.text('Сохранить'), findsNothing);
    expect(find.textContaining('₽'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('увольнение — панель снизу, выбранная дата видна', (
    tester,
  ) async {
    await setUpData(tester, operator: false);
    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Уволить'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Увольнение Иванов Иван Иванович'), findsOneWidget);

    // Без причины — подсказка у поля, окно не закрывается.
    await tester.tap(find.widgetWithText(FilledButton, 'Уволить'));
    await tester.pump();
    expect(find.text('Укажите причину увольнения'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'По собственному');
    await tester.tap(find.widgetWithText(FilledButton, 'Уволить'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    final e = await tester.runAsync(() => repos.employees.byId(id));
    expect(e!.dismissalDate, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
