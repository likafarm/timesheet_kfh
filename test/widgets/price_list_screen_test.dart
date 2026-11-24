import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/providers/price_list_provider.dart';
import 'package:kfx_time_tracking/screens/price_import_screen.dart';
import 'package:kfx_time_tracking/screens/price_list_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:provider/provider.dart';

/// Экран «Прайс-лист» (11.1): прайс по группам, новая редакция, новый
/// товар, история цены; у оператора — только просмотр.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LocalDatabase db;
  late AppProvider app;

  Future<void> setUpApp(WidgetTester tester, {bool operator = false}) async {
    await tester.runAsync(() async {
      await initializeDateFormatting('ru');
      db = LocalDatabase.memory();
      app = AppProvider(AppDatabase(db, ':memory:'), operatorMode: operator);
      final p = DriftRepositories(db).priceList;
      await p.saveGroup(const ProductGroup(id: 'g1', name: 'Говядина'));
      await p.saveProduct(
        const Product(id: 'p1', groupId: 'g1', name: 'Вырезка'),
      );
      await p.savePrices([
        ProductPrice(
          id: 'x1',
          productId: 'p1',
          validFrom: DateTime(2026, 3, 1),
          price: 184000,
        ),
      ]);
    });
    addTearDown(() => tester.runAsync(db.close));
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(home: PriceListScreen()),
      ),
    );
    await settle(tester);
  }

  Future<void> settleImpl(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('новая редакция, новый товар и история цены', (tester) async {
    await setUpApp(tester);
    expect(find.text('Вырезка'), findsOneWidget);
    expect(find.textContaining('1 840 ₽ / кг'), findsOneWidget);
    expect(find.textContaining('Вводится с 01.03.2026'), findsOneWidget);

    // Новая редакция: цена вырезки +5 %.
    await tester.tap(find.text('Новая редакция'));
    await settleImpl(tester);
    await tester.enterText(find.byType(TextField).first, '1932');
    await tester.pump();
    expect(find.text('+5 %'), findsOneWidget);
    await tester.tap(find.text('Сохранить'));
    await settleImpl(tester);
    expect(find.textContaining('1 932 ₽ / кг'), findsOneWidget);
    final prices = await tester.runAsync(
      () => DriftRepositories(db).priceList.prices(),
    );
    expect(prices!.map((p) => p.price), containsAll([184000, 193200]));

    // История: обе цены.
    await tester.tap(find.text('Вырезка'));
    await settleImpl(tester);
    expect(find.textContaining('1 840 ₽'), findsOneWidget);
    expect(find.textContaining('по '), findsOneWidget);
    await tester.tap(find.text('Закрыть'));
    await settleImpl(tester);

    // Новый товар в справочнике — с первой ценой.
    await tester.tap(find.text('Товары и порядок'));
    await settleImpl(tester);
    await tester.tap(find.text('Товар'));
    await settleImpl(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Наименование'),
      'Голова',
    );
    await tester.tap(find.text('шт'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Цена, ₽ за шт'),
      '1000',
    );
    await tester.tap(find.text('Сохранить'));
    await settleImpl(tester);
    expect(find.text('Голова'), findsOneWidget);
    final products = await tester.runAsync(
      () => DriftRepositories(db).priceList.products(),
    );
    expect(
      products!.firstWhere((p) => p.name == 'Голова').unit,
      ProductUnit.pcs,
    );

    // Новая группа и перетаскивание «Головы» за ручку в неё.
    await tester.tap(find.text('Новая группа'));
    await settleImpl(tester);
    await tester.enterText(find.byType(TextField).last, 'Субпродукты');
    await tester.tap(find.text('Сохранить'));
    await settleImpl(tester);
    final handles = find.byIcon(Icons.drag_handle);
    // Говядина, Вырезка, Голова, Субпродукты.
    expect(handles, findsNWidgets(4));
    final gesture = await tester.startGesture(tester.getCenter(handles.at(2)));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await settleImpl(tester);
    final moved = await tester.runAsync(() async {
      final repo = DriftRepositories(db).priceList;
      final groups = await repo.groups();
      final head = (await repo.products()).firstWhere(
        (p) => p.name == 'Голова',
      );
      return groups.firstWhere((g) => g.id == head.groupId).name;
    });
    expect(moved, 'Субпродукты');
    expect(tester.takeException(), isNull);
  });

  testWidgets('загрузка из Excel: проверка и запись', (tester) async {
    await setUpApp(tester);
    final file = parsePriceSheet([
      ['Прайс-лист, вводится с 01.12.2026'],
      ['№', 'Наименование продукции', 'Цена, руб.', 'Единица'],
      [null, 'Говядина'],
      ['1', 'Вырезка', '1932', 'кг'],
      [null, 'Субпродукты'],
      ['2', 'Голова', '1000', 'шт'],
    ]);
    final prices = PriceListProvider(app);
    await tester.runAsync(prices.load);
    addTearDown(prices.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: MaterialApp(
          home: ChangeNotifierProvider.value(
            value: prices,
            child: PriceImportScreen(initial: file, initialName: 'прайс.xlsx'),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Вводится с 01.12.2026'), findsOneWidget);
    expect(find.text('Новых товаров: 1'), findsOneWidget);
    expect(find.text('Новых цен: 1'), findsOneWidget);
    expect(find.textContaining('Было 1 840 ₽, +5 %'), findsOneWidget);
    await tester.tap(find.text('Записать'));
    await settle(tester);
    final saved = await tester.runAsync(
      () => DriftRepositories(db).priceList.prices(),
    );
    expect(
      saved!.map((p) => (p.price, p.validFrom)),
      containsAll([
        (193200, DateTime(2026, 12, 1)),
        (100000, DateTime(2026, 12, 1)),
      ]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('оператор: просмотр и печать, без правки', (tester) async {
    await setUpApp(tester, operator: true);
    expect(find.text('Вырезка'), findsOneWidget);
    expect(find.byTooltip('Печать / PDF'), findsOneWidget);
    expect(find.text('Новая редакция'), findsNothing);
    expect(find.text('Товары и порядок'), findsNothing);
  });
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pumpAndSettle();
}
