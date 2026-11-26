import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/providers/orders_provider.dart';
import 'package:kfx_time_tracking/screens/history_import_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// «Перенести историю из Excel» (11.7): проверка перед записью, выбор
/// товара вручную, перенос, повтор не задваивает, оплата — до программы.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LocalDatabase db;
  late AppProvider app;
  late OrdersProvider orders;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }
  }

  final source = parseHistoryWorkbook([
    [
      [
        'Оплата',
        'Срок поставки',
        'ФИО',
        'Заказ',
        'Номер заказа',
        'Телефон',
        'Вес',
      ],
      ['да', '45780', 'Ольга', 'вырезка 2 кг', '305-1', '89001234567', '2.2'],
      [
        'да',
        '45780',
        'Ольга К.',
        'гречневая каша',
        '305-1 (2/2)',
        '89001234567',
        null,
      ],
      ['да', '45780', 'Пётр', 'язык', '305-2', null, null],
    ],
  ]);

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: ChangeNotifierProvider.value(
          value: orders,
          child: MaterialApp(
            key: UniqueKey(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => HistoryImportScreen(initial: source),
                    ),
                  ),
                  child: const Text('открыть'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('открыть'));
    await settle(tester);
  }

  testWidgets('проверка, свой товар, перенос, повтор', (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await initializeDateFormatting('ru');
      SharedPreferences.setMockInitialValues({});
      db = LocalDatabase.memory();
      app = AppProvider(AppDatabase(db, ':memory:'), operatorMode: false);
      final repos = DriftRepositories(db);
      await repos.priceList.saveGroup(
        const ProductGroup(id: 'g', name: 'Говядина'),
      );
      await repos.priceList.saveProduct(
        const Product(id: 'vyr', groupId: 'g', name: 'Вырезка'),
      );
      await repos.priceList.saveProduct(
        const Product(id: 'liver', groupId: 'g', name: 'Печень'),
      );
      orders = OrdersProvider(app);
      await orders.load();
    });
    addTearDown(() => tester.runAsync(db.close));
    addTearDown(() => orders.dispose());
    await open(tester);

    expect(find.text('Что будет перенесено'), findsOneWidget);
    expect(find.text('Заказов'), findsOneWidget);
    // «Каша» не узнана — в «Прочем» (раскрыто); «Язык» — нет в прайсе.
    expect(find.text(historyOtherProduct), findsOneWidget);
    expect(find.text('гречневая каша'), findsOneWidget);
    expect(find.textContaining('Ольга / Ольга К.'), findsOneWidget);
    // Свой выбор: каша → «Печень».
    await tester.tap(find.text('гречневая каша'));
    await settle(tester);
    await tester.tap(find.text('Печень'));
    await settle(tester);
    expect(find.text(historyOtherProduct), findsNothing);

    await tester.tap(find.text('Перенести'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    final repos = DriftRepositories(db);
    final saved = (await tester.runAsync(repos.orders.orders))!;
    expect(saved.length, 2);
    expect(saved.every((o) => o.fromHistory), isTrue);
    expect(saved.map((o) => o.status).toSet(), {OrderStatus.issued});
    final lines = (await tester.runAsync(repos.orders.lines))!;
    expect(lines.map((l) => l.productId), contains('liver'));
    final customers = (await tester.runAsync(repos.customers.customers))!;
    expect(customers.length, 2, reason: 'Ольга по телефону — одна');
    // Оплата перенесённых — до программы: долгов нет.
    await tester.runAsync(orders.load);
    expect(orders.debtOrders, isEmpty);
    for (final o in saved) {
      expect(orders.paymentOf(o).state, isNot(PaymentState.unpaid));
    }

    // Повтор того же файла — переносить нечего.
    await open(tester);
    expect(
      find.text('Переносить нечего — всё из этого файла уже перенесено.'),
      findsOneWidget,
    );
    expect(find.text('Перенести'), findsNothing);
  });
}
