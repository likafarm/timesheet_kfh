import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:kfx_time_tracking/widgets/daily_timesheet_dialog.dart';
import 'package:provider/provider.dart';

/// Групповой ввод Windows («Быстрый ввод за день»): вопрос о сохранении при
/// закрытии окна и смене даты (шаг 2 «Дальнейших работ»).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LocalDatabase db;
  late DriftRepositories repos;
  late AppProvider app;
  final ids = <String>[];
  final day = DateTime(2026, 9, 3);
  var savedCalls = 0;

  /// Иванов (на 3 сентября уже отмечен: поле), Петров и Сидорова — без
  /// отметок.
  Future<void> openDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    savedCalls = 0;
    await tester.runAsync(() async {
      db = LocalDatabase.memory();
      repos = DriftRepositories(db);
      app = AppProvider(AppDatabase(db, ':memory:'));
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
              baseRate: 1000,
              fieldRate: 1500,
            ),
          ),
        );
      }
      await repos.timesheet.add(
        TimesheetRecord(
          employeeId: ids[0],
          date: day,
          days: 1,
          workPlace: 'field',
          notes: 'заметка',
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
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => DailyTimesheetDialog(
                    initialDate: day,
                    onSaved: () => savedCalls++,
                  ),
                ),
                child: const Text('открыть'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('открыть'));
    await settle(tester);
    expect(find.text('Быстрый ввод за день'), findsOneWidget);
  }

  Future<TimesheetRecord?> savedOn(WidgetTester tester, int i, [DateTime? d]) =>
      tester.runAsync<TimesheetRecord?>(
        () => repos.timesheet.on(ids[i], d ?? day),
      );

  /// Выбрать место работы сотруднику [i]: `База` или `Поле`.
  Future<void> choosePlace(WidgetTester tester, int i, String label) async {
    await tester.tap(find.byKey(ValueKey('place-${ids[i]}')));
    await settle(tester);
    await tester.tap(find.textContaining('$label (').last);
    await settle(tester);
  }

  Future<void> tapClose(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Закрыть'));
    await settle(tester);
  }

  final question = find.text('Сохранить изменения за 03.09.2026?');

  testWidgets('без изменений окно закрывается без вопроса', (tester) async {
    await openDialog(tester);
    // Снятая галочка — не изменение: такая строка в базу не пишется.
    await tester.tap(find.byType(Checkbox).at(2));
    await settle(tester);
    await tapClose(tester);
    expect(question, findsNothing);
    expect(find.text('Быстрый ввод за день'), findsNothing);
    expect(await savedOn(tester, 1), isNull);
  });

  testWidgets('крестик с изменениями: Вернуться, Не сохранять', (tester) async {
    await openDialog(tester);
    await choosePlace(tester, 1, 'Поле');
    await tapClose(tester);
    expect(question, findsOneWidget);
    expect(find.text('Не сохранено изменений: 1'), findsOneWidget);
    expect(
      find.textContaining('Петров П. П.: — → Поле', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.text('Вернуться'));
    await settle(tester);
    expect(question, findsNothing);
    expect(find.text('Быстрый ввод за день'), findsOneWidget);

    await tapClose(tester);
    await tester.tap(find.text('Не сохранять'));
    await settle(tester);
    expect(find.text('Быстрый ввод за день'), findsNothing);
    expect(await savedOn(tester, 1), isNull);
    expect(savedCalls, 0);
  });

  testWidgets('Esc и щелчок мимо окна тоже спрашивают', (tester) async {
    await openDialog(tester);
    await choosePlace(tester, 0, 'База');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(question, findsOneWidget);
    expect(
      find.textContaining('Иванов И. И.: Поле → База', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.text('Вернуться'));
    await settle(tester);

    await tester.tapAt(const Offset(5, 5));
    await settle(tester);
    expect(question, findsOneWidget);
    await tester.tap(find.text('Вернуться'));
    await settle(tester);
    expect(find.text('Быстрый ввод за день'), findsOneWidget);
  });

  testWidgets('Сохранить пишет только изменённые строки', (tester) async {
    await openDialog(tester);
    await choosePlace(tester, 0, 'База');
    await choosePlace(tester, 1, 'Поле');
    await tapClose(tester);
    expect(find.text('Не сохранено изменений: 2'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить').last);
    await settle(tester);

    expect(find.text('Быстрый ввод за день'), findsNothing);
    final ivanov = (await savedOn(tester, 0))!;
    expect((ivanov.workPlace, ivanov.notes), ('base', 'заметка'));
    expect((await savedOn(tester, 1))!.workPlace, 'field');
    // Сидорова осталась с отметкой по умолчанию — её не трогаем.
    expect(await savedOn(tester, 2), isNull);
    expect(savedCalls, 1);
  });

  testWidgets('рабочий день без места не сохраняется — остаёмся в окне', (
    tester,
  ) async {
    await openDialog(tester);
    await tester.tap(find.byKey(ValueKey('days-${ids[1]}')));
    await settle(tester);
    await tester.tap(find.text('0.5').last);
    await settle(tester);
    await tapClose(tester);
    expect(
      find.textContaining('— → ½ дня, место не указано', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить').last);
    await settle(tester);
    expect(find.textContaining('необходимо указать место'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(find.text('Быстрый ввод за день'), findsOneWidget);
    expect(await savedOn(tester, 1), isNull);
  });

  testWidgets('смена даты: вопрос, сохранение и чистый новый день', (
    tester,
  ) async {
    await openDialog(tester);
    await tester.tap(find.byKey(ValueKey('type-${ids[2]}')));
    await settle(tester);
    await tester.tap(find.text('Отпуск').last);
    await settle(tester);

    await tester.tap(find.text('Дата'));
    await settle(tester);
    await tester.tap(find.text('2').last);
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(question, findsOneWidget);
    expect(
      find.textContaining('Сидорова А. С.: — → Отпуск', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить').last);
    await settle(tester);

    expect(find.text('02.09.2026'), findsOneWidget);
    expect((await savedOn(tester, 2))!.dayType, 'vacation');
    expect(await savedOn(tester, 2, DateTime(2026, 9, 2)), isNull);
    expect(savedCalls, 1);

    // Новый день открыт заново: прежний выбор в него не переехал.
    await tapClose(tester);
    expect(find.textContaining('Сохранить изменения'), findsNothing);
    expect(find.text('Быстрый ввод за день'), findsNothing);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
  // Окна и меню успевают закрыться.
  await tester.pump(const Duration(milliseconds: 600));
}
