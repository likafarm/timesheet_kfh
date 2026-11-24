import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

void main() {
  const meat = ProductGroup(id: 'g1', name: 'Говядина охлаждённая');
  const offal = ProductGroup(
    id: 'g2',
    name: 'Субпродукты говяжьи',
    sortOrder: 1,
  );
  const tenderloin = Product(id: 'p1', groupId: 'g1', name: 'Вырезка');
  const set = Product(
    id: 'p2',
    groupId: 'g1',
    name: 'Говядина охлаждённая (набор)',
    sortOrder: 1,
  );
  const head = Product(
    id: 'p3',
    groupId: 'g2',
    name: 'Голова',
    unit: ProductUnit.pcs,
  );
  const udder = Product(id: 'p4', groupId: 'g2', name: 'Вымя', hidden: true);

  final prices = [
    ProductPrice(
      id: 'a',
      productId: 'p1',
      validFrom: DateTime(2025, 5, 1),
      price: 160000,
    ),
    ProductPrice(
      id: 'b',
      productId: 'p1',
      validFrom: DateTime(2026, 3, 1),
      price: 184000,
    ),
    ProductPrice(
      id: 'c',
      productId: 'p2',
      validFrom: DateTime(2025, 5, 1),
      price: 80000,
    ),
    ProductPrice(
      id: 'd',
      productId: 'p3',
      validFrom: DateTime(2026, 3, 1),
      price: 100000,
    ),
    ProductPrice(
      id: 'e',
      productId: 'p4',
      validFrom: DateTime(2026, 3, 1),
      price: 40000,
    ),
  ];

  group('цена на дату', () {
    test('действует последняя начавшаяся цена', () {
      expect(priceAt(prices, 'p1', DateTime(2025, 4, 30)), isNull);
      expect(priceAt(prices, 'p1', DateTime(2025, 5, 1))!.price, 160000);
      expect(priceAt(prices, 'p1', DateTime(2026, 2, 28))!.price, 160000);
      expect(priceAt(prices, 'p1', DateTime(2026, 3, 1))!.price, 184000);
      // Время суток не влияет.
      expect(priceAt(prices, 'p1', DateTime(2026, 3, 1, 0, 30))!.price, 184000);
    });

    test('прежняя цена', () {
      expect(previousPrice(prices, prices[1])!.id, 'a');
      expect(previousPrice(prices, prices[0]), isNull);
    });

    test('редакции — дни начала цен, новые сначала', () {
      expect(priceEditions(prices), [
        DateTime(2026, 3, 1),
        DateTime(2025, 5, 1),
      ]);
      expect(editionAt(prices, DateTime(2026, 2, 1)), DateTime(2025, 5, 1));
      expect(editionAt(prices, DateTime(2026, 11, 24)), DateTime(2026, 3, 1));
      expect(editionAt(prices, DateTime(2025, 1, 1)), isNull);
    });
  });

  group('прайс на дату', () {
    test('группы и товары по порядку, скрытые не печатаются', () {
      final view = buildPriceList(
        groups: [offal, meat],
        products: [head, set, tenderloin, udder],
        prices: prices,
        day: DateTime(2026, 11, 24),
      );
      expect(view.edition, DateTime(2026, 3, 1));
      expect(view.sections.map((s) => s.group.name), [
        'Говядина охлаждённая',
        'Субпродукты говяжьи',
      ]);
      expect(view.rows.map((r) => r.product.name), [
        'Вырезка',
        'Говядина охлаждённая (набор)',
        'Голова',
      ]);
      final first = view.rows.first;
      expect(first.price!.price, 184000);
      expect(first.changedInEdition, isTrue);
      expect(first.change, closeTo(0.15, 1e-9));
      // Набор в редакции 01.03.2026 не менялся.
      final second = view.rows.elementAt(1);
      expect(second.changedInEdition, isFalse);
      expect(second.change, isNull);
      // Голова — первая цена: изменения нет.
      expect(view.rows.last.change, isNull);
    });

    test('со скрытыми и только с ценой', () {
      final all = buildPriceList(
        groups: [meat, offal],
        products: [head, set, tenderloin, udder],
        prices: prices,
        day: DateTime(2025, 6, 1),
        includeHidden: true,
      );
      expect(all.rows.length, 4);
      final priced = buildPriceList(
        groups: [meat, offal],
        products: [head, set, tenderloin, udder],
        prices: prices,
        day: DateTime(2025, 6, 1),
        includeHidden: true,
        onlyPriced: true,
      );
      expect(priced.sections.single.group.id, 'g1');
      expect(priced.edition, DateTime(2025, 5, 1));
    });
  });

  group('новая редакция', () {
    var n = 0;
    String newId() => 'new${++n}';

    test('меняется только то, что отличается', () {
      final changes = planPriceEdition(
        prices: prices,
        from: DateTime(2026, 12, 1),
        newPrices: {'p1': 184000, 'p2': 92000, 'p3': 110000},
        newId: newId,
      );
      expect(changes.map((c) => (c.productId, c.price, c.validFrom)), [
        ('p2', 92000, DateTime(2026, 12, 1)),
        ('p3', 110000, DateTime(2026, 12, 1)),
      ]);
      expect(changes.every((c) => c.id.startsWith('new')), isTrue);
    });

    test('цена с того же дня исправляется, а не дублируется', () {
      final changes = planPriceEdition(
        prices: prices,
        from: DateTime(2026, 3, 1),
        newPrices: {'p1': 185000},
        newId: newId,
      );
      expect(changes.single.id, 'b');
      expect(changes.single.price, 185000);
    });

    test('новый товар получает первую цену', () {
      final changes = planPriceEdition(
        prices: prices,
        from: DateTime(2026, 3, 1),
        newPrices: {'p9': 6000},
        newId: newId,
      );
      expect(changes.single.productId, 'p9');
    });
  });

  test('история цен: новые сначала, с периодом и изменением', () {
    final history = priceHistory(prices, 'p1');
    expect(history.map((h) => h.price.id), ['b', 'a']);
    expect(history.first.until, isNull);
    expect(history.last.until, DateTime(2026, 2, 28));
    expect(history.first.change, closeTo(0.15, 1e-9));
    expect(history.last.change, isNull);
  });

  group('проверки', () {
    test('цена больше нуля', () {
      final p = ProductPrice(
        id: 'x',
        productId: 'p1',
        validFrom: DateTime(2026, 1, 1),
        price: 0,
      );
      expect(productPriceProblem(p), isNotNull);
      expect(productPriceProblem(p.copyWith(price: 1)), isNull);
    });

    test('название товара и группы', () {
      expect(productProblem(tenderloin.copyWith(name: '  ')), isNotNull);
      expect(productProblem(tenderloin), isNull);
      expect(productGroupProblem(meat.copyWith(name: '')), isNotNull);
      expect(salesRowProblem('products', {'name': ' '}), isNotNull);
      expect(salesRowProblem('product_groups', {'name': 'Мясо'}), isNull);
      expect(salesRowProblem('fin_operations', {}), isNull);
    });
  });

  test('вид цены и изменения', () {
    // Разряды — через неразрывный пробел (как formatRub).
    expect(formatPrice(184000), '1 840');
    expect(formatPrice(9250), '92,50');
    expect(formatPriceChange(0.15), '+15 %');
    expect(formatPriceChange(-0.0531), '−5,3 %');
    expect(formatPriceChange(0.00001), '0 %');
  });
}
