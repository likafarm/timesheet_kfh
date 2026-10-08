import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/providers/finance_provider.dart';
import 'package:kfx_time_tracking/screens/finance_balances_screen.dart';
import 'package:kfx_time_tracking/screens/finance_catalog_screen.dart';
import 'package:kfx_time_tracking/screens/finance_reports_screen.dart';
import 'package:kfx_time_tracking/screens/finance_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:kfx_time_tracking/widgets/common_widgets.dart';
import 'package:provider/provider.dart';

/// Раздел «Финансы» (8.5): список месяца, отбор, запись операции.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LocalDatabase db;
  late AppProvider app;
  final today = calendarDay(DateTime.now());

  Future<void> setUpApp(WidgetTester tester) async {
    await tester.runAsync(() async {
      await initializeDateFormatting('ru');
      db = LocalDatabase.memory();
      app = AppProvider(AppDatabase(db, ':memory:'), operatorMode: false);
      final f = DriftRepositories(db).finance;
      await f.saveDirection(
        const FinDirection(id: 'd1', name: 'Животноводство'),
      );
      await f.saveAccount(
        const FinAccount(id: 'a1', name: 'Касса', kind: AccountKind.cash),
      );
      await f.saveAccount(
        const FinAccount(id: 'a2', name: 'Карта', kind: AccountKind.card),
      );
      await f.saveCategory(
        const FinCategory(
          id: 'c1',
          type: CategoryType.expense,
          group: '05',
          name: 'Корма покупные',
          directionId: 'd1',
        ),
      );
      await f.addOperation(
        FinOperation(
          id: 'op-1',
          date: today,
          type: OperationType.expense,
          amount: 250000,
          accountId: 'a2',
          categoryId: 'c1',
          description: 'Комбикорм',
        ),
      );
    });
    addTearDown(() => tester.runAsync(db.close));
  }

  /// Пункт меню «Финансов» (8Б.1) с общей моделью, как в главном окне.
  Widget section(Widget screen) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: app),
      ChangeNotifierProvider(create: (_) => FinanceProvider(app)..load()),
    ],
    child: MaterialApp(home: screen),
  );

  Future<void> settle(
    WidgetTester tester, [
    Future<void> Function()? act,
  ]) async {
    await tester.runAsync(() async {
      await act?.call();
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('список месяца, отбор по кошельку, новая операция', (
    tester,
  ) async {
    await setUpApp(tester);
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(home: FinanceScreen()),
      ),
    );
    await settle(tester);
    expect(find.text('Комбикорм'), findsOneWidget);
    expect(find.text('Корма покупные'), findsOneWidget);

    // Отбор: кошелёк «Касса» — операций нет.
    await tester.tap(find.text('Все').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Касса').last);
    await tester.pumpAndSettle();
    expect(find.text('Комбикорм'), findsNothing);
    expect(find.textContaining('Нет операций по отбору'), findsOneWidget);
    await tester.tap(find.text('Сбросить'));
    await tester.pumpAndSettle();
    expect(find.text('Комбикорм'), findsOneWidget);

    // Новая операция: сумма, статья поиском, кошелёк по умолчанию.
    await tester.tap(find.byTooltip('Новая операция'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Сумма, ₽ *'),
      '1 200,50',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Статья *'), 'корм');
    await tester.pumpAndSettle();
    await tester.tap(find.text('05'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Что (товар, услуга)'),
      'Сено',
    );
    await settle(tester, () async {
      await tester.tap(find.text('Добавить'));
      await tester.pump();
    });
    expect(find.text('Сено'), findsOneWidget);
    final saved = await tester.runAsync(
      () => DriftRepositories(db).finance.operations(),
    );
    final hay = saved!.firstWhere((o) => o.description == 'Сено');
    expect(hay.amount, 120050);
    expect(hay.categoryId, 'c1');
    expect(hay.accountId, 'a2', reason: 'первый открытый кошелёк — «Карта»');
  });

  testWidgets('остатки, сверка с корректировкой, отбор по кошельку', (
    tester,
  ) async {
    await setUpApp(tester);
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(section(const FinanceBalancesScreen()));
    await settle(tester);
    expect(find.text('Банки и кассы'), findsOneWidget);
    expect(find.text('Кошельки'), findsOneWidget);
    expect(find.text('${formatRub(-250000)} ₽'), findsWidgets);
    expect(find.text('Долгов нет'), findsOneWidget);

    // Сверка «Карты»: по записям −2 500, факт −2 400 — излишек 100.
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Карта'),
        matching: find.byTooltip('Сверить остаток'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Сверка остатка'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Фактический остаток, ₽'),
      '-2400',
    );
    await tester.pumpAndSettle();
    expect(find.text('Излишек — запишется доходом'), findsOneWidget);
    await settle(tester, () async {
      await tester.tap(find.text('Записать корректировку'));
      await tester.pump();
    });
    expect(find.text('Сверка остатка'), findsNothing);
    expect(find.text('${formatRub(-240000)} ₽'), findsWidgets);
    final ops = await tester.runAsync(
      () => DriftRepositories(db).finance.operations(),
    );
    final fix = ops!.firstWhere((o) => o.type == OperationType.income);
    expect(fix.amount, 10000);
    expect(fix.accountId, 'a2');
    expect(fix.date, today);

    // Нажатие на кошелёк — его операции за месяц.
    // У «Карты» и вид — «Карта»: строка находится дважды.
    await tester.tap(find.widgetWithText(ListTile, 'Карта').first);
    await tester.pumpAndSettle();
    expect(find.text('Кошельки'), findsNothing);
    expect(find.text('Корректировка по сверке остатка'), findsOneWidget);
    expect(find.textContaining('Остаток «Карта»'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('справочники: статьи по группам, новая группа', (tester) async {
    await setUpApp(tester);
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(section(const FinanceCatalogScreen()));
    await settle(tester);
    expect(find.text('Займы'), findsNothing, reason: 'займы — свой пункт');
    await tester.tap(find.text('Статьи'));
    await tester.pumpAndSettle();
    // Группа «05» есть только текстом у статьи (запись старой программы).
    expect(find.text('05 (нет в справочнике) · расходы'), findsOneWidget);

    await tester.tap(find.text('Группы статей'));
    await tester.pumpAndSettle();
    expect(find.text('Групп нет'), findsOneWidget);
    await tester.tap(find.byTooltip('Добавить'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Название *'), '05');
    await settle(tester, () async {
      await tester.tap(find.text('Сохранить'));
      await tester.pump();
    });
    expect(find.text('расходы · статей: 1 · порядок 1'), findsOneWidget);

    await tester.tap(find.text('Статьи'));
    await tester.pumpAndSettle();
    expect(find.text('05 · расходы'), findsOneWidget);
    await tester.tap(find.text('Корма покупные'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppDropdown<String?>, '05'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('по месяцам: статьи и направления, переход к операциям', (
    tester,
  ) async {
    await setUpApp(tester);
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(section(const FinanceReportsScreen()));
    await settle(tester);
    await tester.tap(find.text('Доходы и расходы по месяцам'));
    await tester.pumpAndSettle();
    expect(find.text('${today.year}'), findsOneWidget);
    expect(find.text('Корма покупные'), findsOneWidget);
    expect(find.text('05'), findsOneWidget, reason: 'группа статьи');
    expect(find.text('Итог: доходы − расходы'), findsOneWidget);

    await tester.tap(find.text('По направлениям'));
    await tester.pumpAndSettle();
    expect(find.text('Корма покупные'), findsNothing);
    expect(find.text('Животноводство'), findsOneWidget);

    await tester.tap(find.text('По статьям'));
    await tester.pumpAndSettle();
    // Нажатие на сумму месяца — список операций с отбором.
    final row = find
        .ancestor(of: find.text('Корма покупные'), matching: find.byType(Row))
        .first;
    await tester.tap(
      find.descendant(of: row, matching: find.byType(InkWell)).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Комбикорм'), findsOneWidget);
    expect(find.text('Корма покупные (расход)'), findsOneWidget);

    // Назад — к отчётам.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Себестоимость кормов: направления «растениеводство» нет — первое.
    await tester.tap(find.text('Себестоимость кормов'));
    await tester.pumpAndSettle();
    expect(find.text('Сезон ${today.year}'), findsOneWidget);
    expect(find.text('Корма покупные'), findsOneWidget);
    expect(find.text('Итог: выручка − затраты'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Прошлый год — пусто.
    await tester.tap(find.text('Доходы и расходы по месяцам'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Предыдущий год'));
    await tester.pumpAndSettle();
    expect(
      find.text('Нет доходов и расходов за ${today.year - 1} год'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('управленческий баланс: актив, пассив, капитал (8Б.2)', (
    tester,
  ) async {
    await setUpApp(tester);
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(section(const FinanceReportsScreen()));
    await settle(tester);
    await settle(tester, () async {
      await tester.tap(find.text('Управленческий баланс'));
      await tester.pump();
    });
    expect(find.text('Итого актив'), findsOneWidget);
    expect(find.text('Итого пассив'), findsOneWidget);
    expect(find.text('Капитал (актив − пассив)'), findsOneWidget);
    // Карта ушла в минус на 2 500 — она в пассиве.
    expect(find.text('Кредитные карты и кошельки в минусе'), findsOneWidget);
    expect(find.text('Карта'), findsOneWidget);
    expect(find.text('${formatRub(-250000)} ₽'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ДДС: остатки и потоки по видам деятельности (8Б.3)', (
    tester,
  ) async {
    await setUpApp(tester);
    tester.view.physicalSize = const Size(1700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(section(const FinanceReportsScreen()));
    await settle(tester);
    await tester.tap(find.text('Движение денег (ДДС)'));
    await tester.pumpAndSettle();
    expect(find.text('Деньги на начало месяца'), findsOneWidget);
    expect(find.text('Итого операционная'), findsOneWidget);
    expect(find.text('Корма покупные'), findsOneWidget);
    expect(find.text('Деньги на конец месяца'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
