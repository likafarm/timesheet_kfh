import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/screens/daily_input_screen.dart';
import 'package:kfx_time_tracking/screens/timesheet_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:kfx_time_tracking/widgets/timesheet_record_dialog.dart';
import 'package:provider/provider.dart';

/// Ввод табеля на телефоне (шаг 4.4): одно касание — запись, сетка табеля
/// открывает день одиночным касанием и не вылезает за край экрана.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() => initializeDateFormatting('ru'));

  late LocalDatabase db;
  late DriftRepositories repos;
  late AppProvider app;
  final ids = <String>[];
  final day = DateTime(2026, 9, 3);

  Future<void> setUpData(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      db = LocalDatabase.memory();
      repos = DriftRepositories(db);
      app = AppProvider(AppDatabase(db, ':memory:'), operatorMode: true);
      ids.clear();
      for (final name in [
        'Иванов Иван Иванович',
        'Петров Пётр Петрович',
        'Сидорова Анна Сергеевна',
      ]) {
        ids.add(
          await repos.employees.add(
            Employee(
              fullName: name,
              position: 'Рабочий',
              hireDate: DateTime(2025, 3, 1),
              baseRate: 0,
              fieldRate: 0,
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
  }

  Widget wrap(Widget home) => ChangeNotifierProvider.value(
    value: app,
    child: MaterialApp(home: home),
  );

  testWidgets('отметка одним касанием, очистка', (tester) async {
    await setUpData(tester);
    await tester.pumpWidget(wrap(DailyInputScreen(initialDate: day)));
    await settle(tester);
    expect(find.text('Отмечено 0 из 3'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Поле').first);
    await settle(tester);
    var saved = await tester.runAsync(() => repos.timesheet.on(ids[0], day));
    expect(saved!.dayType, 'work');
    expect(saved.workPlace, 'field');
    expect(saved.days, 1);
    expect(find.text('Отмечено 1 из 3'), findsOneWidget);

    // Другая отметка того же дня — та же запись, место работы снято.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Больничный').first);
    await settle(tester);
    saved = await tester.runAsync(() => repos.timesheet.on(ids[0], day));
    expect(saved!.dayType, 'sick');
    expect(saved.workPlace, isNull);

    await tester.tap(find.byTooltip('Очистить отметку'));
    await settle(tester);
    saved = await tester.runAsync(() => repos.timesheet.on(ids[0], day));
    expect(saved, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('закрытый месяц — кнопки недоступны', (tester) async {
    await setUpData(tester);
    await tester.runAsync(() async {
      await LocalSyncStore(db).saveLockedMonths([(2026, 9)]);
      await app.loadLockedMonths();
    });
    await tester.pumpWidget(wrap(DailyInputScreen(initialDate: day)));
    await settle(tester);
    expect(find.textContaining('Месяц закрыт'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'База').first,
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('табель на телефоне: влезает, день открывается одним касанием', (
    tester,
  ) async {
    await setUpData(tester);
    await tester.pumpWidget(wrap(const TimesheetScreen()));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Табель'), findsOneWidget);
    // Оператору — без печати и расчёта ЗП.
    expect(find.byTooltip('Печать табеля'), findsNothing);
    expect(find.byTooltip('Рассчитать зарплату за месяц'), findsNothing);

    // Первая ячейка первого сотрудника — одно касание.
    final cell = find.byKey(ValueKey('timesheet-cell-${ids[0]}-1'));
    await tester.tap(cell);
    await settle(tester);
    expect(find.byType(TimesheetRecordDialog), findsOneWidget);
    // На телефоне — панель снизу, а не окно по центру.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
