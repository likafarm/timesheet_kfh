import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/screens/daily_input_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:kfx_time_tracking/widgets/timesheet_record_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ввод за день на компьютере и в браузере (решение владельца 2026-10-06):
/// тот же экран, что на телефоне, строками; клавиши 1–7, ↑/↓, Delete,
/// Ctrl+S; «Всем без отметки» с выбором отметки. Окно ячейки табеля —
/// кнопки отметок вместо выпадающих списков.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() => initializeDateFormatting('ru'));

  late LocalDatabase db;
  late DriftRepositories repos;
  late AppProvider app;
  final ids = <String>[];
  final day = DateTime(2026, 9, 3);

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
      for (final name in [
        'Иванов Иван Иванович',
        'Петров Пётр Петрович',
        'Сидорова Анна Сергеевна',
        'Яковлев Олег Павлович',
      ]) {
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

  Widget wrap(Widget home) => ChangeNotifierProvider.value(
    value: app,
    child: MaterialApp(home: home),
  );

  Future<TimesheetRecord?> savedOn(WidgetTester tester, int i) async =>
      await tester.runAsync<TimesheetRecord?>(
        () => repos.timesheet.on(ids[i], day),
      );

  testWidgets('строки вместо карточек, клавиши ставят отметки и сохраняют', (
    tester,
  ) async {
    await setUpData(tester);
    await tester.pumpWidget(wrap(DailyInputScreen(initialDate: day)));
    await settle(tester);
    expect(find.byType(Card), findsNothing);
    expect(find.textContaining('Клавиши: 1–7'), findsOneWidget);
    expect(find.text('Отмечено 0 из 4'), findsOneWidget);

    // Первая строка мышью, дальше — с клавиатуры: строка под клавишами
    // сама переходит вниз.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Поле').first);
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1); // База
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad5); // Больничный
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4); // ½ поле
    await settle(tester);
    expect(find.text('Отмечено 4 из 4'), findsOneWidget);
    expect(find.text('Не сохранено: 4'), findsOneWidget);

    // Последняя строка остаётся под клавишами — очистить её.
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await settle(tester);
    expect(find.text('Не сохранено: 3'), findsOneWidget);
    expect(await savedOn(tester, 0), isNull);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(find.text('Сохранено отметок: 3'), findsOneWidget);
    expect((await savedOn(tester, 0))!.workPlace, 'field');
    final second = (await savedOn(tester, 1))!;
    expect((second.dayType, second.days, second.workPlace), (
      'work',
      1.0,
      'base',
    ));
    expect((await savedOn(tester, 2))!.dayType, 'sick');
    expect(await savedOn(tester, 3), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('«Всем без отметки»: выбранная отметка — только тем, у кого '
      'её нет', (tester) async {
    await setUpData(tester);
    await tester.runAsync(
      () => repos.timesheet.add(
        TimesheetRecord(
          employeeId: ids[0],
          date: day,
          dayType: 'vacation',
          days: 1,
        ),
      ),
    );
    await tester.pumpWidget(wrap(DailyInputScreen(initialDate: day)));
    await settle(tester);
    // У второго — отметка в черновике.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Выходной').at(1));
    await settle(tester);

    await tester.tap(find.text('Всем без отметки'));
    await settle(tester);
    await tester.tap(find.widgetWithText(MenuItemButton, '½ база'));
    await settle(tester);
    expect(find.text('«½ база» — отмечено: 2'), findsOneWidget);
    expect(find.text('Отмечено 4 из 4'), findsOneWidget);
    // Все отмечены — кнопка недоступна.
    final fill = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Всем без отметки'),
        matching: find.byWidgetPredicate((w) => w is TextButton),
      ),
    );
    expect(fill.onPressed, isNull);

    await tester.tap(find.text('Сохранить'));
    await settle(tester);
    expect((await savedOn(tester, 0))!.dayType, 'vacation');
    expect((await savedOn(tester, 1))!.dayType, 'dayoff');
    for (final i in [2, 3]) {
      final r = (await savedOn(tester, i))!;
      expect((r.dayType, r.days, r.workPlace), ('work', 0.5, 'base'));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('окно ячейки: отметка кнопками, без отметки не сохраняет', (
    tester,
  ) async {
    await setUpData(tester);
    final employee = app.employees.firstWhere((e) => e.id == ids[0]);
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => TimesheetRecordDialog(
                  employee: employee,
                  defaultDate: day,
                ),
              ),
              child: const Text('открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('открыть'));
    await settle(tester);
    expect(find.byType(DropdownButton<String>), findsNothing);

    await tester.tap(find.text('Добавить'));
    await settle(tester);
    expect(find.text('Выберите отметку дня'), findsOneWidget);
    expect(await savedOn(tester, 0), isNull);

    await tester.tap(find.widgetWithText(OutlinedButton, '½ поле'));
    await settle(tester);
    expect(find.textContaining('Ставка в поле'), findsOneWidget);
    await tester.tap(find.text('Добавить'));
    await settle(tester);
    expect(find.byType(TimesheetRecordDialog), findsNothing);
    final r = (await savedOn(tester, 0))!;
    expect((r.dayType, r.days, r.workPlace), ('work', 0.5, 'field'));
    expect(tester.takeException(), isNull);
  });
}
