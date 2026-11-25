import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/providers/orders_provider.dart';
import 'package:kfx_time_tracking/screens/batches_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:kfx_time_tracking/services/batch_pdf.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// «Продажи → Выдачи» (11.5): сборочный лист, взвешивание подряд (набор —
/// по частям), заказ сам становится «Собран», «Не хватило», печать.
/// Посмотреть PDF: `KFH_BATCH_OUT=<папка> flutter test
/// test/widgets/batches_screen_test.dart`.
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
      ..salesMode = true;
    final repos = DriftRepositories(db);
    final current = await repos.settings.get();
    await repos.settings.save(
      current.copyWith(companyName: 'КФХ «Пример»', phone: '+7 900 000-00-00'),
    );
    await app.loadCompanySettings();
    await repos.customers.saveCustomer(
      const Customer(id: 'c1', name: 'Ольга', phone: '89001234567'),
    );
    await repos.customers.saveCustomer(
      const Customer(id: 'c2', name: 'Пётр', address: 'Юхнов, Ленина 1'),
    );
    await repos.priceList.saveGroup(
      const ProductGroup(id: 'g1', name: 'Говядина'),
    );
    const products = [
      ('vyr', 'Вырезка', ProductUnit.kg, 1840),
      ('set', 'Набор', ProductUnit.kg, 920),
      ('rib', 'Ребро', ProductUnit.kg, 700),
      ('head', 'Голова', ProductUnit.pcs, 1000),
    ];
    for (final (i, (id, name, unit, _)) in products.indexed) {
      await repos.priceList.saveProduct(
        Product(id: id, groupId: 'g1', name: name, unit: unit, sortOrder: i),
      );
    }
    await repos.priceList.savePrices([
      for (final (id, _, _, rub) in products)
        ProductPrice(
          id: 'x$id',
          productId: id,
          validFrom: DateTime(2026, 3, 1),
          price: rub * 100,
        ),
    ]);
    await repos.orders.saveBatch(SaleBatch(id: 'b1', day: day));
    await repos.orders.saveOrder(
      const SaleOrder(id: 'o1', batchId: 'b1', customerId: 'c1', number: 1),
      const [
        SaleOrderLine(
          id: 'l1',
          orderId: 'o1',
          productId: 'vyr',
          orderedQty: 2,
          orderedUnit: OrderedUnit.kg,
          price: 184000,
        ),
        SaleOrderLine(
          id: 'l2',
          orderId: 'o1',
          productId: 'set',
          sortOrder: 1,
          orderedQty: 3,
          orderedUnit: OrderedUnit.kg,
          price: 92000,
        ),
        SaleOrderLine(
          id: 'l2a',
          orderId: 'o1',
          parentId: 'l2',
          productId: 'rib',
          price: 70000,
        ),
      ],
    );
    await repos.orders.saveOrder(
      const SaleOrder(
        id: 'o2',
        batchId: 'b1',
        customerId: 'c2',
        number: 2,
        delivery: Delivery.delivery,
      ),
      const [
        SaleOrderLine(
          id: 'l3',
          orderId: 'o2',
          productId: 'head',
          orderedQty: 1,
          orderedUnit: OrderedUnit.pcs,
          price: 100000,
        ),
      ],
    );
  }

  testWidgets('взвешивание подряд: набор по частям, заказ — «Собран»', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(seed);
    addTearDown(() => tester.runAsync(db.close));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(home: BatchesScreen()),
      ),
    );
    await settle(tester);
    expect(find.textContaining('заказов: 2'), findsOneWidget);
    await tester.tap(find.textContaining('заказов: 2'));
    await settle(tester);
    // Сборочный лист: товары и кому; части набора — внутри набора.
    expect(find.text('Сборочный лист'), findsOneWidget);
    expect(find.widgetWithText(ExpansionTile, 'Вырезка'), findsOneWidget);
    expect(find.widgetWithText(ExpansionTile, 'Голова'), findsOneWidget);
    final setCard = find.widgetWithText(ExpansionTile, 'Набор');
    expect(setCard, findsWidgets);
    expect(
      find.descendant(of: setCard.first, matching: find.text('Ребро')),
      findsOneWidget,
      reason: 'ребро — внутри набора',
    );
    expect(find.textContaining('состав: Ребро ×1'), findsOneWidget);
    // Свернуть всё — частей не видно; развернуть — снова видно.
    await tester.tap(find.text('Свернуть всё'));
    await settle(tester);
    expect(find.text('Ребро'), findsNothing);
    await tester.tap(find.text('Развернуть всё'));
    await settle(tester);
    expect(find.text('Ребро'), findsOneWidget);
    // Итог — под сборочным листом.
    await tester.scrollUntilVisible(find.text('Итог выдачи'), 200);
    expect(find.text('По товарам'), findsOneWidget);
    await tester.tap(find.text('Взвешивать (3)'));
    await settle(tester);
    // Первая — вырезка Ольги: 2,6 кг — больше заказанного на 30 %.
    expect(find.text('Вырезка'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Вес'), '2,6');
    await tester.pump();
    expect(find.text('Больше заказанного на 30 %'), findsOneWidget);
    await tester.tap(find.text('Записать и дальше'));
    await settle(tester);
    // Часть набора: ход сборки набора.
    expect(find.text('часть набора «Набор»'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Вес'), '3,1');
    await tester.pump();
    expect(
      find.textContaining('Собрано 3,1 кг из 3 кг · перебор 0,1 кг · на 2'),
      findsOneWidget,
      reason: (tester.widgetList<Text>(find.byType(Text)))
          .map((t) => t.data)
          .where((d) => d != null && d.contains('Собрано'))
          .join('|'),
    );
    await tester.tap(find.text('Записать и дальше'));
    await settle(tester);
    // Голова Петра — не хватило.
    expect(find.text('Голова'), findsOneWidget);
    await tester.tap(find.text('Не хватило'));
    await settle(tester);
    await tester.tap(find.text('Снять'));
    await settle(tester);
    expect(find.text('Всё взвешено'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final p = OrdersProvider(app);
    await tester.runAsync(p.load);
    final o1 = p.orders.firstWhere((o) => o.id == 'o1');
    expect(o1.status, OrderStatus.assembled, reason: 'всё взвешено');
    final set = p.linesOf('o1').firstWhere((l) => l.id == 'l2');
    expect(set.state, LineState.assembled, reason: 'набор — по частям');
    // К оплате: вырезка 2,6 × 1840 + набор 3,1 × 920.
    expect(p.totals('o1').due, 478400 + 285200);
    expect(p.totals('o1').complete, isTrue);
    final head = p.linesOf('o2').single;
    expect(head.state, LineState.missing);
    expect(head.note, 'не хватило');
    expect(
      p.orders.firstWhere((o) => o.id == 'o2').status,
      OrderStatus.assembled,
      reason: 'снятая строка тоже закрывает сборку',
    );

    // Печать: пакеты (пометка о расхождении), бирки, маршрут.
    final data = batchPrintData(p, p.batch('b1')!);
    expect(data.orders.length, 2);
    expect(data.orders.first.warning, isNotNull);
    expect(data.orders.last.warning, isNull, reason: 'снятое не в счёт');
    // Бирки: вырезка и набор (с составом) — отдельно; снятой головы нет.
    final tags = batchTags(data);
    expect(tags.map((t) => t.line.product), ['Вырезка', 'Набор']);
    expect(tags.last.line.composition, 'Ребро 3,1');
    expect(tags.first.count, 2);
    // Этикетка: группа прайса, цена за единицу, день выдачи.
    expect(tags.first.line.group, 'Говядина');
    expect(tags.first.line.ordered, '2 кг');
    expect(tags.first.line.price, startsWith('1'));
    expect(tags.first.line.price, endsWith('₽/кг'));
    expect(data.day, matches(RegExp(r'^\d\d\.\d\d\.\d{4}$')));
    expect(data.orders.last.delivery, isTrue);
    Future<ByteData> asset(String path) async =>
        ByteData.sublistView(await File(path).readAsBytes());
    final out = Platform.environment['KFH_BATCH_OUT'];
    await tester.runAsync(() async {
      for (final (name, build) in [
        ('пакеты', buildBatchPackagesPdf),
        ('бирки', buildBatchTagsPdf),
        ('этикетки', buildBatchLabelsPdf),
        ('маршрут', buildBatchRoutePdf),
      ]) {
        final bytes = await build(data, asset: asset);
        expect(bytes.length, greaterThan(1000));
        if (out != null) {
          await File('$out/выдача_$name.pdf').writeAsBytes(bytes);
        }
      }
    });
    p.dispose();
  });

  testWidgets('телефон: выдача и весы помещаются', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(seed);
    addTearDown(() => tester.runAsync(db.close));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(home: BatchesScreen()),
      ),
    );
    await settle(tester);
    await tester.tap(find.textContaining('заказов: 2'));
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'сборочный лист');
    await tester.scrollUntilVisible(find.text('По товарам'), 200);
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'итог');
    await tester.tap(find.text('Взвешивать (3)'));
    await settle(tester);
    expect(find.text('Записать и дальше'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'весы');

    // Ничего не взвешено: на этикетке — места для записи ручкой.
    final p = OrdersProvider(app);
    await tester.runAsync(p.load);
    final data = batchPrintData(p, p.batch('b1')!);
    expect(batchTags(data).every((t) => t.line.fact.isEmpty), isTrue);
    final out = Platform.environment['KFH_BATCH_OUT'];
    await tester.runAsync(() async {
      final bytes = await buildBatchLabelsPdf(
        data,
        asset: (path) async =>
            ByteData.sublistView(await File(path).readAsBytes()),
      );
      expect(bytes.length, greaterThan(1000));
      if (out != null) {
        await File('$out/выдача_этикетки_пустые.pdf').writeAsBytes(bytes);
      }
    });
    p.dispose();
  });
}
