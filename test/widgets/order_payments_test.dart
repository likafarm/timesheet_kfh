import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/providers/orders_provider.dart';
import 'package:kfx_time_tracking/screens/orders_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Оплата заказов (11.6): оплата из карточки заказа — доход в финансах со
/// ссылкой на заказ, покупатель — контрагент; долг, переплата, возврат,
/// фильтр «Долги», сообщение покупателю.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LocalDatabase db;
  late AppProvider app;
  final day = calendarDay(DateTime.now());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> seed() async {
    await initializeDateFormatting('ru');
    SharedPreferences.setMockInitialValues({});
    db = LocalDatabase.memory();
    app = AppProvider(AppDatabase(db, ':memory:'), operatorMode: false)
      ..salesMode = true
      ..userUuid = 'seller';
    final repos = DriftRepositories(db);
    await repos.finance.saveDirection(
      const FinDirection(id: 'sale', name: 'Реализация'),
    );
    await repos.finance.saveAccount(
      const FinAccount(id: 'cash', name: 'Касса', kind: AccountKind.cash),
    );
    await repos.finance.saveAccount(
      const FinAccount(id: 'card', name: 'Карта', kind: AccountKind.card),
    );
    await repos.finance.saveCategory(
      const FinCategory(
        id: 'meat',
        type: CategoryType.income,
        group: 'Реализация',
        name: 'Реализация мяса',
      ),
    );
    await repos.finance.saveCategory(
      const FinCategory(
        id: 'refund',
        type: CategoryType.expense,
        group: 'Прочее',
        name: 'Возврат покупателю',
      ),
    );
    await repos.customers.saveCustomer(
      const Customer(id: 'c1', name: 'Ольга', phone: '89001234567'),
    );
    await repos.priceList.saveGroup(
      const ProductGroup(id: 'g1', name: 'Говядина'),
    );
    await repos.priceList.saveProduct(
      const Product(id: 'vyr', groupId: 'g1', name: 'Вырезка'),
    );
    await repos.orders.saveBatch(SaleBatch(id: 'b1', day: day));
    // Выдан: 2,5 кг × 1 840 = 4 600 ₽.
    await repos.orders.saveOrder(
      const SaleOrder(
        id: 'o1',
        batchId: 'b1',
        customerId: 'c1',
        number: 1,
        status: OrderStatus.issued,
      ),
      const [
        SaleOrderLine(
          id: 'l1',
          orderId: 'o1',
          productId: 'vyr',
          orderedQty: 2,
          orderedUnit: OrderedUnit.kg,
          weight: 2.5,
          price: 184000,
          state: LineState.assembled,
        ),
      ],
    );
  }

  Future<void> openOrder(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(home: OrdersScreen()),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Ольга'));
    await settle(tester);
  }

  testWidgets('оплата частями: доход в финансах, покупатель — контрагент', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(seed);
    addTearDown(() => tester.runAsync(db.close));
    await openOrder(tester);
    expect(find.text('Не оплачен'), findsOneWidget);

    // Часть — 3 000 ₽ наличными.
    await tester.tap(find.widgetWithText(FilledButton, 'Оплата'));
    await settle(tester);
    expect(
      find.widgetWithText(TextField, '4600'),
      findsOneWidget,
      reason: 'подсказана сумма к оплате',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Сумма'), '3000');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Касса'));
    await tester.tap(find.text('Записать оплату'));
    await settle(tester);
    expect(find.textContaining('Осталось доплатить 1'), findsOneWidget);
    expect(find.textContaining('должен'), findsOneWidget);

    // Остаток — картой.
    await tester.tap(find.widgetWithText(FilledButton, 'Оплата'));
    await settle(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Карта'));
    await tester.tap(find.text('Записать оплату'));
    await settle(tester);
    expect(find.text('Оплачен'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final repos = DriftRepositories(db);
    final ops = await tester.runAsync(repos.finance.operations);
    expect(ops!.length, 2);
    expect(ops.map((o) => o.sourceRef).toSet(), {'order:o1'});
    expect(ops.map((o) => o.type).toSet(), {OperationType.income});
    expect(ops.map((o) => o.categoryId).toSet(), {'meat'});
    expect(ops.map((o) => o.createdBy).toSet(), {'seller'});
    expect(ops.fold<int>(0, (s, o) => s + o.amount), 460000);
    expect(ops.map((o) => o.accountId).toSet(), {'cash', 'card'});
    // Покупатель стал контрагентом финансов (один раз).
    final customer = (await tester.runAsync(repos.customers.customers))!.single;
    expect(customer.counterpartyId, isNotNull);
    expect(ops.map((o) => o.counterpartyId).toSet(), {customer.counterpartyId});
    final counterparties = await tester.runAsync(repos.finance.counterparties);
    expect(counterparties!.single.name, 'Ольга');
    expect(counterparties.single.kind, CounterpartyKind.buyer);
  });

  testWidgets('переплата — аванс, возврат — расход; «Долги» и сообщение', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(seed);
    addTearDown(() => tester.runAsync(db.close));
    final p = OrdersProvider(app);
    await tester.runAsync(p.load);
    final order = p.orders.single;
    // В «Долгах» — выданный неоплаченный.
    expect(p.debtOrders.map((o) => o.id), ['o1']);
    await tester.runAsync(
      () => p.addPayment(
        order,
        amount: 500000,
        accountId: 'cash',
        categoryId: 'meat',
        date: day,
      ),
    );
    expect(p.lastProblem, isNull);
    expect(p.paymentOf(order).state, PaymentState.overpaid);
    expect(p.balanceOf('c1').advance, 40000);
    expect(p.debtOrders, isEmpty);
    // Вернули 400 ₽ — расход «Возврат покупателю».
    await tester.runAsync(
      () => p.addPayment(
        order,
        amount: 40000,
        accountId: 'cash',
        categoryId: 'refund',
        date: day,
        refund: true,
      ),
    );
    expect(p.paymentOf(order).state, PaymentState.paid);
    expect(p.balanceOf('c1').balance, 0);
    final message = p.customerMessage(order);
    expect(message, contains('Ольга'));
    expect(message, contains('Вырезка — 2,5 кг'));
    expect(message, contains('К оплате: 4'));
    // «Без оплаты» дохода не принимает.
    final free = order.copyWith(kind: OrderKind.free);
    expect(
      await tester.runAsync(
        () => p.addPayment(
          free,
          amount: 100,
          accountId: 'cash',
          categoryId: 'meat',
          date: day,
        ),
      ),
      isFalse,
    );
    p.dispose();

    // Окно сообщения: копировать в буфер.
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    await openOrder(tester);
    await tester.tap(find.text('Сообщение покупателю'));
    await settle(tester);
    await tester.tap(find.text('Копировать'));
    await settle(tester);
    expect(copied.single, contains('Ваш заказ'));
    expect(tester.takeException(), isNull);
  });
}
