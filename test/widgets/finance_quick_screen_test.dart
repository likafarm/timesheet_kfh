import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/providers/finance_provider.dart';
import 'package:kfx_time_tracking/screens/finance_quick_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:provider/provider.dart';

/// Быстрый ввод с телефона (8.6): последняя статья — кнопкой, кошелёк —
/// последний, сумма крупно.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LocalDatabase db;
  late AppProvider app;
  late FinanceProvider fin;

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
      await f.saveCounterparty(const Counterparty(id: 'p1', name: 'Агроторг'));
      await f.addOperation(
        FinOperation(
          id: 'op-old',
          date: DateTime(2026, 9, 1),
          type: OperationType.expense,
          amount: 1000,
          accountId: 'a1',
          categoryId: 'c1',
          counterpartyId: 'p1',
        ),
      );
      fin = FinanceProvider(app);
      await fin.load();
    });
    addTearDown(
      () => tester.runAsync(() async {
        fin.dispose();
        await db.close();
      }),
    );
  }

  testWidgets('расход в три касания', (tester) async {
    await setUpApp(tester);
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bool? result;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await openQuickOperation(context, fin),
                child: const Text('открыть'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '350');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Корма покупные'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Агроторг'));
    await tester.pumpAndSettle();
    expect(find.text('Записать расход 350,00 ₽'), findsOneWidget);
    expect(find.text('Направление: По статье: Животноводство'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Записать расход 350,00 ₽'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(result, isTrue);
    final ops = await tester.runAsync(
      () => DriftRepositories(db).finance.operations(),
    );
    final added = ops!.firstWhere((o) => o.id != 'op-old');
    expect(added.amount, 35000);
    expect(added.categoryId, 'c1');
    expect(added.counterpartyId, 'p1');
    expect(added.accountId, 'a1', reason: 'кошелёк последнего расхода');
    expect(added.date, calendarDay(DateTime.now()));
  });
}
