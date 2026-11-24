import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/providers/price_list_provider.dart';
import 'package:kfx_time_tracking/services/app_database.dart';

/// Модель прайс-листа (11.1) на базе в памяти.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LocalDatabase db;
  late AppProvider app;
  late PriceListProvider prices;

  setUp(() async {
    db = LocalDatabase.memory();
    app = AppProvider(AppDatabase(db, ':memory:'), operatorMode: false);
    prices = PriceListProvider(app);
    await prices.load();
  });

  tearDown(() async {
    prices.dispose();
    await db.close();
  });

  Future<void> seed() async {
    expect(
      await prices.saveGroup(const ProductGroup(id: 'g1', name: 'Говядина')),
      isTrue,
    );
    expect(
      await prices.saveProduct(
        const Product(id: 'p1', groupId: 'g1', name: 'Вырезка'),
        firstPrice: 160000,
        priceFrom: DateTime(2025, 5, 1),
      ),
      isTrue,
    );
    expect(
      await prices.saveProduct(
        const Product(id: 'p2', groupId: 'g1', name: 'Пашина', sortOrder: 1),
        firstPrice: 40000,
        priceFrom: DateTime(2025, 5, 1),
      ),
      isTrue,
    );
  }

  test(
    'новая редакция пишет только изменённые цены, история остаётся',
    () async {
      await seed();
      final saved = await prices.saveEdition(DateTime(2026, 3, 1), {
        'p1': 184000,
        'p2': 40000,
      });
      expect(saved, 1);
      expect(prices.editions, [DateTime(2026, 3, 1), DateTime(2025, 5, 1)]);
      final view = prices.view(DateTime(2026, 3, 1));
      expect(view.rows.first.price!.price, 184000);
      expect(view.rows.first.change, closeTo(0.15, 1e-9));
      expect(prices.history('p1').map((h) => h.price.price), [184000, 160000]);

      // Ничего не изменилось — не пишется.
      expect(
        await prices.saveEdition(DateTime(2026, 3, 1), {'p1': 184000}),
        isNull,
      );
      expect(prices.lastProblem, contains('не изменились'));
    },
  );

  test('исправить и удалить ошибочную цену', () async {
    await seed();
    await prices.saveEdition(DateTime(2026, 3, 1), {'p1': 1840000});
    final wrong = priceAt(prices.prices, 'p1', DateTime(2026, 3, 1))!;
    expect(await prices.correctPrice(wrong, 184000), isTrue);
    expect(priceAt(prices.prices, 'p1', DateTime(2026, 4, 1))!.price, 184000);
    expect(await prices.deletePrice(wrong.id), isTrue);
    expect(priceAt(prices.prices, 'p1', DateTime(2026, 4, 1))!.price, 160000);
  });

  test('товар с ценами не удаляется, его можно скрыть', () async {
    await seed();
    expect(await prices.deleteProduct('p1'), isFalse);
    expect(prices.lastProblem, contains('скрыть'));
    final p1 = prices.product('p1')!;
    expect(await prices.saveProduct(p1.copyWith(hidden: true)), isTrue);
    expect(prices.view(DateTime(2026, 1, 1)).rows.map((r) => r.product.id), [
      'p2',
    ]);
    expect(await prices.deleteGroup('g1'), isFalse);
  });

  test('повтор названия и порядок товаров', () async {
    await seed();
    expect(
      await prices.saveProduct(
        const Product(id: 'p3', groupId: 'g1', name: 'Вырезка'),
      ),
      isFalse,
    );
    final siblings = productsOfGroup(prices.products, 'g1');
    expect(await prices.moveProduct(siblings, 1, -1), isTrue);
    expect(productsOfGroup(prices.products, 'g1').map((p) => p.id), [
      'p2',
      'p1',
    ]);
  });

  test('оператор прайс не правит', () async {
    app.operatorMode = true;
    expect(prices.canEdit, isFalse);
    expect(
      await prices.saveGroup(const ProductGroup(id: 'g1', name: 'Говядина')),
      isFalse,
    );
    expect(await DriftRepositories(db).priceList.groups(), isEmpty);
  });
}
