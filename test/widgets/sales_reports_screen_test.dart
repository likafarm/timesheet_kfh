import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/screens/sales_reports_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:kfx_time_tracking/services/excel_export.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// «Отчёты по продажам» (11.8): четыре вида на компьютере и телефоне,
/// выгрузка в Excel.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LocalDatabase db;
  late AppProvider app;
  final year = DateTime.now().year;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
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
    app = AppProvider(AppDatabase(db, ':memory:'), operatorMode: false);
    final repos = DriftRepositories(db);
    await repos.customers.saveCustomer(const Customer(id: 'c1', name: 'Ольга'));
    await repos.customers.saveCustomer(const Customer(id: 'c2', name: 'Пётр'));
    await repos.priceList.saveGroup(
      const ProductGroup(id: 'g1', name: 'Говядина'),
    );
    await repos.priceList.saveProduct(
      const Product(id: 'vyr', groupId: 'g1', name: 'Вырезка'),
    );
    await repos.orders.saveBatch(
      SaleBatch(id: 'b1', day: DateTime(year, 1, 10)),
    );
    await repos.orders.saveBatch(
      SaleBatch(id: 'b2', day: DateTime(year, 2, 14)),
    );
    for (final (id, batch, customer, weight, state) in [
      ('o1', 'b1', 'c1', 2.5, LineState.assembled),
      ('o2', 'b2', 'c1', 1.0, LineState.assembled),
      ('o3', 'b2', 'c2', null, LineState.missing),
    ]) {
      await repos.orders.saveOrder(
        SaleOrder(
          id: id,
          batchId: batch,
          customerId: customer,
          number: 1,
          status: OrderStatus.issued,
        ),
        [
          SaleOrderLine(
            id: 'l$id',
            orderId: id,
            productId: 'vyr',
            orderedQty: 2,
            orderedUnit: OrderedUnit.kg,
            weight: weight,
            price: 200000,
            state: state,
          ),
        ],
      );
    }
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(home: SalesReportsScreen()),
      ),
    );
    await settle(tester);
  }

  for (final (name, size) in [
    ('компьютер', const Size(1280, 900)),
    ('телефон', const Size(390, 844)),
  ]) {
    testWidgets('четыре вида отчёта — $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(seed);
      addTearDown(() => tester.runAsync(db.close));
      await open(tester);
      // По товарам: 3,5 кг на 7 000 ₽, средняя 2 000 ₽/кг.
      expect(find.textContaining('Выручка: 7'), findsOneWidget);
      expect(find.text('3,5 кг'), findsOneWidget);
      await tester.tap(find.text('По месяцам'));
      await settle(tester);
      expect(find.text('2,5 кг'), findsOneWidget, reason: 'январь');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('По выдачам'));
      await settle(tester);
      expect(find.textContaining('Выдач: 2'), findsOneWidget);
      await tester.tap(find.text('Заказано и выдано'));
      await settle(tester);
      expect(find.textContaining('1 раз'), findsOneWidget, reason: 'Пётр');
      await tester.tap(find.text('Покупатели'));
      await settle(tester);
      expect(find.text('Ольга'), findsOneWidget);
      expect(find.textContaining('долг'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  test('Excel: четыре листа', () async {
    await seed();
    final repos = DriftRepositories(db);
    final data = SalesData(
      batches: await repos.orders.batches(),
      orders: await repos.orders.orders(),
      lines: await repos.orders.lines(),
      products: {for (final p in await repos.priceList.products()) p.id: p},
    );
    const period = SalesPeriod();
    final book = salesReportWorkbook(
      periodTitle: 'весь период',
      products: productSales(data, period),
      batches: batchSales(data, period),
      ordered: orderedVsIssued(data, period),
      customers: customerSales(data, period),
      productName: (id) => id,
      customerName: (id) => id,
      batchName: (b) => b.id,
      today: DateTime.now(),
    );
    final bytes = book.encode();
    expect(bytes.length, greaterThan(1000));
    final out = Platform.environment['KFH_XLSX_OUT'];
    if (out != null) {
      await File('$out/продажи.xlsx').writeAsBytes(bytes);
    }
    await db.close();
  });
}
