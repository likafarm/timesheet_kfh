import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/screens/orders_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// «Продажи → Заказы» (11.4): новый заказ — покупатель, товар из прайса,
/// заказано 2 кг; номер ДДМ-1 и предварительная сумма; факт — к оплате.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  testWidgets('новый заказ: покупатель, товар, заказано и факт', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await initializeDateFormatting('ru');
      db = LocalDatabase.memory();
      app = AppProvider(AppDatabase(db, ':memory:'), operatorMode: false)
        ..salesMode = true;
      final repos = DriftRepositories(db);
      await repos.customers.saveCustomer(
        const Customer(id: 'c1', name: 'Ольга', address: 'Юхнов'),
      );
      await repos.priceList.saveGroup(
        const ProductGroup(id: 'g1', name: 'Говядина'),
      );
      await repos.priceList.saveProduct(
        const Product(id: 'p1', groupId: 'g1', name: 'Вырезка'),
      );
      await repos.priceList.savePrices([
        ProductPrice(
          id: 'x1',
          productId: 'p1',
          validFrom: DateTime(2026, 3, 1),
          price: 184000,
        ),
      ]);
    });
    addTearDown(() => tester.runAsync(db.close));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(home: OrdersScreen()),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('Заказ'));
    await settle(tester);
    expect(find.text('Новый заказ'), findsOneWidget);

    // Покупатель.
    await tester.tap(find.text('Выберите покупателя'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'оль');
    await settle(tester);
    await tester.tap(find.text('Ольга').last);
    await settle(tester);

    // Товар: 2 кг.
    await tester.tap(find.widgetWithText(FilledButton, 'Товар'));
    await settle(tester);
    await tester.tap(find.text('Вырезка'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Сколько'), '2');
    await tester.tap(find.text('Готово'));
    await settle(tester);
    expect(find.text('Предварительно ≈ 3 680 ₽'), findsOneWidget);

    await tester.tap(find.text('Сохранить'));
    await settle(tester);
    final code = '${day.day}${day.month}-1';
    expect(find.text(code), findsOneWidget, reason: 'номер ДДМ-N');
    expect(find.textContaining('Вырезка 2 кг'), findsOneWidget);
    expect(find.text('≈ 3 680 ₽'), findsOneWidget);

    // Факт 2,6 кг — к оплате по факту, отклонение подсвечено.
    await tester.tap(find.text('Ольга'));
    await settle(tester);
    await tester.tap(find.text('Вырезка'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Вес'), '2,6');
    await tester.tap(find.text('Готово'));
    await settle(tester);
    expect(find.text('К оплате 4 784 ₽'), findsOneWidget);
    await tester.tap(find.text('Сохранить'));
    await settle(tester);

    final saved = await tester.runAsync(() async {
      final o = DriftRepositories(db).orders;
      return (await o.orders(), await o.lines(), await o.batches());
    });
    final (orders, lines, batches) = saved!;
    expect(orders.single.customerId, 'c1');
    expect(orders.single.number, 1);
    expect(batches.single.day, day);
    expect(lines.single.orderedQty, 2);
    expect(lines.single.weight, 2.6);
    expect(lines.single.state, LineState.assembled);
    expect(lines.single.price, 184000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('телефон: карточка заказа и окно строки помещаются', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await initializeDateFormatting('ru');
      db = LocalDatabase.memory();
      app = AppProvider(AppDatabase(db, ':memory:'), operatorMode: false)
        ..salesMode = true;
      final repos = DriftRepositories(db);
      await repos.priceList.saveGroup(
        const ProductGroup(id: 'g1', name: 'Говядина'),
      );
      await repos.priceList.saveProduct(
        const Product(
          id: 'p1',
          groupId: 'g1',
          name: 'Говядина охлаждённая (набор)',
        ),
      );
    });
    addTearDown(() => tester.runAsync(db.close));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(home: OrdersScreen()),
      ),
    );
    await settle(tester);
    expect(find.text('Покупатель'), findsNothing, reason: 'телефон — карточки');
    await tester.tap(find.text('Заказ'));
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'карточка заказа');
    await tester.tap(find.widgetWithText(FilledButton, 'Товар'));
    await settle(tester);
    await tester.tap(find.text('Говядина охлаждённая (набор)'));
    await settle(tester);
    expect(find.text('Сколько'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'окно строки');
  });

  testWidgets('набор: при сборке видно, сколько набрано и сколько осталось', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await initializeDateFormatting('ru');
      db = LocalDatabase.memory();
      app = AppProvider(AppDatabase(db, ':memory:'), operatorMode: false)
        ..salesMode = true;
      final repos = DriftRepositories(db);
      await repos.customers.saveCustomer(
        const Customer(id: 'c1', name: 'Ольга'),
      );
      await repos.priceList.saveGroup(
        const ProductGroup(id: 'g1', name: 'Говядина'),
      );
      await repos.priceList.saveProduct(
        const Product(id: 'set', groupId: 'g1', name: 'Набор'),
      );
      await repos.priceList.saveProduct(
        const Product(id: 'rib', groupId: 'g1', name: 'Ребро', sortOrder: 1),
      );
    });
    addTearDown(() => tester.runAsync(db.close));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(home: OrdersScreen()),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Заказ'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Товар'));
    await settle(tester);
    await tester.tap(find.text('Набор'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Сколько'), '3');
    await tester.tap(find.text('Состав набора'));
    await settle(tester);
    await tester.tap(find.text('Ребро'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Вес').last, '1,2');
    await tester.pump();
    expect(
      find.text('Собрано 1,2 кг из 3 кг · осталось 1,8 кг'),
      findsOneWidget,
    );
    // Вторая часть — перебор.
    await tester.tap(find.text('Часть набора'));
    await settle(tester);
    // «Ребро» уже есть в составе — нажать в окне выбора (оно поверх).
    await tester.tap(find.text('Ребро').last);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Вес').last, '2');
    await tester.pump();
    expect(
      find.text('Собрано 3,2 кг из 3 кг · перебор 0,2 кг'),
      findsOneWidget,
    );
    await tester.tap(find.text('Готово'));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('«Принят» — принятые заказы всех выдач, и прошедших', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await initializeDateFormatting('ru');
      db = LocalDatabase.memory();
      app = AppProvider(AppDatabase(db, ':memory:'), operatorMode: false)
        ..salesMode = true;
      final repos = DriftRepositories(db);
      await repos.customers.saveCustomer(
        const Customer(id: 'c1', name: 'Ольга'),
      );
      await repos.customers.saveCustomer(
        const Customer(id: 'c2', name: 'Пётр'),
      );
      await repos.customers.saveCustomer(
        const Customer(id: 'c3', name: 'Нина'),
      );
      await repos.priceList.saveGroup(
        const ProductGroup(id: 'g1', name: 'Говядина'),
      );
      await repos.priceList.saveProduct(
        const Product(id: 'p1', groupId: 'g1', name: 'Вырезка'),
      );
      final old = SaleBatch(id: 'b1', day: DateTime(2026, 6, 27));
      final next = SaleBatch(id: 'b2', day: addCalendarDays(day, 3));
      await repos.orders.saveBatch(old);
      await repos.orders.saveBatch(next);
      SaleOrderLine line(String order) => SaleOrderLine(
        id: 'l-$order',
        orderId: order,
        productId: 'p1',
        orderedQty: 1,
      );
      await repos.orders.saveOrder(
        const SaleOrder(id: 'o1', batchId: 'b1', customerId: 'c1', number: 1),
        [line('o1')],
      );
      await repos.orders.saveOrder(
        const SaleOrder(
          id: 'o2',
          batchId: 'b1',
          customerId: 'c2',
          number: 2,
          status: OrderStatus.issued,
        ),
        [line('o2')],
      );
      await repos.orders.saveOrder(
        const SaleOrder(id: 'o3', batchId: 'b2', customerId: 'c3', number: 1),
        [line('o3')],
      );
    });
    addTearDown(() => tester.runAsync(db.close));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(home: OrdersScreen()),
      ),
    );
    await settle(tester);
    // Открыта ближайшая выдача — только её заказ.
    expect(find.textContaining('Нина'), findsWidgets);
    // Компьютер — таблица: заголовок колонок над строками.
    expect(find.text('Покупатель'), findsOneWidget);
    expect(find.text('Состояние'), findsOneWidget);
    expect(find.textContaining('Ольга'), findsNothing);
    await tester.tap(
      find.widgetWithText(ChoiceChip, OrderStatus.accepted.title),
    );
    await settle(tester);
    expect(find.text('Принятые заказы всех выдач'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^Выдача 27.06.2026.* — прошла$')),
      findsOneWidget,
    );
    expect(find.textContaining('Ольга'), findsWidgets);
    expect(find.textContaining('Нина'), findsWidgets);
    expect(find.textContaining('Пётр'), findsNothing, reason: 'выдан');
    expect(tester.takeException(), isNull);
  });

  testWidgets('выбор покупателя: весь список прокручивается без поиска', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await initializeDateFormatting('ru');
      db = LocalDatabase.memory();
      app = AppProvider(AppDatabase(db, ':memory:'), operatorMode: false)
        ..salesMode = true;
      final repos = DriftRepositories(db);
      for (var i = 1; i <= 60; i++) {
        final n = i.toString().padLeft(2, '0');
        await repos.customers.saveCustomer(
          Customer(id: 'c$n', name: 'Покупатель $n'),
        );
      }
    });
    addTearDown(() => tester.runAsync(db.close));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(home: OrdersScreen()),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Заказ'));
    await settle(tester);
    await tester.tap(find.text('Выберите покупателя'));
    await settle(tester);
    expect(find.text('Все покупатели: 60'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Покупатель 60'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tester.tap(find.text('Покупатель 60'));
    await settle(tester);
    expect(find.text('Покупатель 60'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
