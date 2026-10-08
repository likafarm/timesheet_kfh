import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/screens/finance_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
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
}
