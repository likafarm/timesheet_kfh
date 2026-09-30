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
import 'package:kfx_time_tracking/theme/app_theme.dart';
import 'package:kfx_time_tracking/utils/day_draft.dart';
import 'package:kfx_time_tracking/widgets/timesheet_record_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ввод табеля на телефоне (шаг 4.4; 6.10 — черновик с подтверждением),
/// сетка табеля открывает день одиночным касанием и не вылезает за край
/// экрана.
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
    // Окна и страницы успевают закрыться.
    await tester.pump(const Duration(milliseconds: 600));
  }

  Widget wrap(Widget home) => ChangeNotifierProvider.value(
    value: app,
    child: MaterialApp(home: home),
  );

  Future<TimesheetRecord?> savedOn(
    WidgetTester tester,
    int i, [
    DateTime? d,
  ]) async => await tester.runAsync<TimesheetRecord?>(
    () => repos.timesheet.on(ids[i], d ?? day),
  );

  testWidgets('черновик: касание не пишет в базу, «Сохранить» — пишет', (
    tester,
  ) async {
    await setUpData(tester);
    await tester.pumpWidget(wrap(DailyInputScreen(initialDate: day)));
    await settle(tester);
    expect(find.text('Отмечено 0 из 3'), findsOneWidget);
    expect(find.text('Сохранить'), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Поле').first);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Отпуск').at(1));
    await settle(tester);
    expect(await savedOn(tester, 0), isNull);
    expect(find.text('Отмечено 2 из 3'), findsOneWidget);
    expect(find.text('Не сохранено: 2'), findsOneWidget);
    expect(find.textContaining('не сохранено · было: —'), findsNWidgets(2));

    await tester.tap(find.text('Сохранить'));
    await settle(tester);
    var saved = await savedOn(tester, 0);
    expect(saved!.dayType, 'work');
    expect(saved.workPlace, 'field');
    expect((await savedOn(tester, 1))!.dayType, 'vacation');
    expect(find.text('Не сохранено: 2'), findsNothing);
    expect(find.text('Сохранено отметок: 2'), findsOneWidget);

    // Другая отметка той же записи и очистка — тоже через черновик.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Больничный').first);
    await tester.tap(find.byTooltip('Очистить отметку').at(1));
    await settle(tester);
    expect(find.textContaining('было: Поле'), findsOneWidget);
    expect(find.textContaining('было: Отпуск'), findsOneWidget);
    await tester.tap(find.text('Сохранить'));
    await settle(tester);
    saved = await savedOn(tester, 0);
    expect(saved!.dayType, 'sick');
    expect(saved.workPlace, isNull);
    expect(await savedOn(tester, 1), isNull);

    // Вернуть ту же отметку, что в базе, — не правка.
    await tester.tap(find.widgetWithText(OutlinedButton, 'База').first);
    await settle(tester);
    expect(find.text('Не сохранено: 1'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'База').first);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Больничный').first);
    await settle(tester);
    expect(find.text('Не сохранено: 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('уход на другой день: окно со списком — сохранить, '
      'не сохранять, вернуться', (tester) async {
    await setUpData(tester);
    await tester.pumpWidget(wrap(DailyInputScreen(initialDate: day)));
    await settle(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Поле').first);
    await settle(tester);
    await tester.tap(find.byTooltip('Следующий день'));
    await settle(tester);
    expect(find.text('Сохранить отметки за 3 сентября?'), findsOneWidget);
    expect(find.text('Иванов И. И.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.textContaining('было: —', findRichText: true),
      ),
      findsOneWidget,
    );

    // «Вернуться» — день тот же, черновик цел.
    await tester.tap(find.text('Вернуться'));
    await settle(tester);
    expect(find.text('Не сохранено: 1'), findsOneWidget);
    expect(find.textContaining('3 сентября'), findsOneWidget);

    // «Не сохранять» — день сменился, в базе пусто.
    await tester.tap(find.byTooltip('Следующий день'));
    await settle(tester);
    await tester.tap(find.text('Не сохранять'));
    await settle(tester);
    expect(find.textContaining('4 сентября'), findsOneWidget);
    expect(await savedOn(tester, 0), isNull);
    expect(find.text('Не сохранено: 1'), findsNothing);

    // «Сохранить» — записано, затем переход.
    await tester.tap(find.widgetWithText(OutlinedButton, 'База').first);
    await settle(tester);
    await tester.tap(find.byTooltip('Предыдущий день'));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(FilledButton, 'Сохранить'),
      ),
    );
    await settle(tester);
    expect(find.textContaining('3 сентября'), findsOneWidget);
    expect((await savedOn(tester, 0, DateTime(2026, 9, 4)))!.workPlace, 'base');
    expect(tester.takeException(), isNull);
  });

  testWidgets('«Назад» с черновиком — вопрос; правка другим — видна', (
    tester,
  ) async {
    await setUpData(tester);
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      DailyInputScreen(initialDate: day, standalone: true),
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
    await tester.tap(find.widgetWithText(OutlinedButton, 'Поле').first);
    await settle(tester);

    // Тем временем с сервера пришла другая отметка того же сотрудника.
    await tester.runAsync(() async {
      await repos.timesheet.add(
        TimesheetRecord(
          employeeId: ids[0],
          date: day,
          dayType: 'sick',
          days: 1,
        ),
      );
      app.notifyListeners();
    });
    await settle(tester);
    expect(find.text('уже изменено другим: Больничный'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('Уже изменено другим: Больничный'), findsOneWidget);
    await tester.tap(find.text('Вернуться'));
    await settle(tester);
    expect(find.byType(DailyInputScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(FilledButton, 'Сохранить'),
      ),
    );
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DailyInputScreen), findsNothing);
    final saved = await savedOn(tester, 0);
    expect(saved!.dayType, 'work');
    expect(saved.workPlace, 'field');
    expect(tester.takeException(), isNull);
  });

  testWidgets('черновик переживает закрытие программы', (tester) async {
    await setUpData(tester);
    await tester.pumpWidget(wrap(DailyInputScreen(initialDate: day)));
    await settle(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Поле').first);
    await settle(tester);

    // Программу закрыла система — экран исчез без вопросов.
    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pumpWidget(wrap(const TimesheetScreen()));
    await settle(tester);
    expect(
      find.text('Есть несохранённые отметки за 3 сентября (1)'),
      findsOneWidget,
    );

    // Ввод за день открывается на дне черновика с его отметками.
    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pumpWidget(wrap(const DailyInputScreen()));
    await settle(tester);
    expect(find.textContaining('3 сентября 2026'), findsOneWidget);
    expect(find.text('Не сохранено: 1'), findsOneWidget);
    expect(await savedOn(tester, 0), isNull);
    await tester.tap(find.text('Сохранить'));
    await settle(tester);
    expect((await savedOn(tester, 0))!.workPlace, 'field');
    expect(await tester.runAsync(DayDraftStore.load), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('тёмная тема: итоги табеля — тёмный фон, светлый текст', (
    tester,
  ) async {
    await setUpData(tester);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const TimesheetScreen(),
        ),
      ),
    );
    await settle(tester);
    final total = tester.widget<Text>(find.text('0.0').first);
    expect(total.style!.color!.computeLuminance(), greaterThan(0.5));
    final box =
        tester
                .widget<Container>(
                  find
                      .ancestor(
                        of: find.text('0.0').first,
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(box.color!.computeLuminance(), lessThan(0.1));
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
    // Месяц — в строке заголовка вместо названия экрана (как в отчётах).
    expect(find.text('Табель учёта времени'), findsNothing);
    expect(find.byTooltip('Предыдущий месяц'), findsOneWidget);
    expect(find.byTooltip('Текущий месяц'), findsOneWidget);
    expect(find.byTooltip('Ввод за день'), findsOneWidget);
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
    // Оператору — без ставок: ни в шапке, ни в списке мест работы.
    expect(find.textContaining('Ставк'), findsNothing);
    expect(find.textContaining('₽'), findsNothing);
    final places = tester
        .widget<DropdownButton<String?>>(find.byType(DropdownButton<String?>))
        .items!
        .map((i) => (i.child as Text).data)
        .toList();
    expect(places, ['База', 'Поле']);
    expect(find.textContaining('₽'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
