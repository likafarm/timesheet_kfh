import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

/// Заказы (11.4): номер, заказано/факт, суммы, наборы с частями.
void main() {
  const tenderloin = Product(id: 'vyr', groupId: 'g', name: 'Вырезка');
  const head = Product(
    id: 'head',
    groupId: 'g',
    name: 'Голова',
    unit: ProductUnit.pcs,
  );
  const set = Product(id: 'set', groupId: 'g', name: 'Набор');
  const rib = Product(id: 'rib', groupId: 'g', name: 'Ребро');
  const neck = Product(id: 'neck', groupId: 'g', name: 'Шея');
  final products = {
    for (final p in [tenderloin, head, set, rib, neck]) p.id: p,
  };

  SaleOrderLine line(
    String id,
    String product, {
    String? parent,
    double? qty,
    OrderedUnit? unit,
    double? weight,
    int? pieces,
    int? price,
    LinePricing pricing = LinePricing.list,
    int? fixed,
    LineState state = LineState.open,
  }) => SaleOrderLine(
    id: id,
    orderId: 'o1',
    parentId: parent,
    productId: product,
    orderedQty: qty,
    orderedUnit: unit,
    weight: weight,
    pieces: pieces,
    price: price,
    pricing: pricing,
    fixedAmount: fixed,
    state: state,
  );

  test('номер ДДМ-N и следующий номер в выдаче', () {
    final batch = SaleBatch(id: 'b', day: DateTime(2026, 6, 27));
    const order = SaleOrder(
      id: 'o1',
      batchId: 'b',
      customerId: 'c',
      number: 15,
    );
    expect(orderLabel(batch, order), '276-15');
    expect(batchCode(DateTime(2026, 11, 3)), '311');
    expect(nextOrderNumber([order], 'b'), 16);
    expect(nextOrderNumber([order], 'other'), 1);
    expect(batchOn([batch], DateTime(2026, 6, 27, 15)), batch);
  });

  test('предварительно — по заказанному, к оплате — по факту', () {
    final lines = [
      line('1', 'vyr', qty: 2, unit: OrderedUnit.kg, price: 184000),
      line('2', 'head', qty: 1, unit: OrderedUnit.pcs, price: 100000),
    ];
    var t = orderTotals(lines, 'o1', products);
    expect(t.complete, isFalse);
    expect(t.estimate, 368000 + 100000);
    expect(t.due, t.estimate);

    final weighed = [
      lines[0].copyWith(weight: () => 2.6, state: LineState.assembled),
      lines[1].copyWith(pieces: () => 1, state: LineState.assembled),
    ];
    t = orderTotals(weighed, 'o1', products);
    expect(t.complete, isTrue);
    expect(t.fact, 478400 + 100000, reason: '2,6 кг × 1840');
    expect(t.weight, 2.6);
    expect(weightOff(weighed[0]), isTrue, reason: '+30 % > 15 %');
    expect(
      weightOff(weighed[0].copyWith(weight: () => 2.2)),
      isFalse,
      reason: '+10 %',
    );
  });

  test('заказано текстом и «на сумму»', () {
    final lines = [
      line('1', 'vyr', price: 184000),
      line('2', 'vyr', qty: 5000, unit: OrderedUnit.rub, price: 184000),
    ];
    final t = orderTotals(lines, 'o1', products);
    expect(t.unknown, 1);
    expect(t.estimate, 500000);
  });

  test('не выдана — 0, заказ считается собранным', () {
    final lines = [
      line('1', 'vyr', qty: 1, unit: OrderedUnit.kg, price: 184000, weight: 1),
      line(
        '2',
        'head',
        qty: 1,
        unit: OrderedUnit.pcs,
        state: LineState.missing,
      ),
    ];
    final t = orderTotals(lines, 'o1', products);
    expect(t.complete, isTrue);
    expect(t.fact, 184000);
  });

  group('набор с частями', () {
    final parts = [
      line('p1', 'rib', parent: 's', weight: 0.7, price: 57500),
      line('p2', 'neck', parent: 's', weight: 1.3, price: 92000),
    ];

    test('по прайсу набора: общий вес × цена набора', () {
      final s = line('s', 'set', qty: 2, unit: OrderedUnit.kg, price: 92000);
      final t = orderTotals([s, ...parts], 'o1', products);
      expect(t.fact, 184000, reason: '2,0 кг × 920');
      expect(t.weight, closeTo(2.0, 1e-9));
    });

    test('по ценам частей', () {
      final s = line('s', 'set', pricing: LinePricing.parts, price: 92000);
      final t = orderTotals([s, ...parts], 'o1', products);
      expect(t.fact, 40250 + 119600);
    });

    test('своя цена за кг и своя сумма', () {
      final manual = line(
        's',
        'set',
        pricing: LinePricing.manual,
        price: 80000,
      );
      expect(orderTotals([manual, ...parts], 'o1', products).fact, 160000);
      final fixed = line('s', 'set', pricing: LinePricing.fixed, fixed: 150000);
      final t = orderTotals([fixed, ...parts], 'o1', products);
      expect(t.fact, 150000);
      expect(t.estimate, 150000);
    });

    test('ход сборки: набрано, осталось, перебор', () {
      final s = line('s', 'set', qty: 3, unit: OrderedUnit.kg, price: 92000);
      var pr = setProgress(s, parts, products);
      expect(pr.collected, closeTo(2.0, 1e-9));
      expect(pr.leftKg, closeTo(1.0, 1e-9));
      expect(pr.collectedAmount, 184000, reason: '2 кг × 920 по прайсу набора');
      expect(pr.off(), isTrue, reason: 'недобор 33 %');
      final more = [
        ...parts,
        line('p3', 'rib', parent: 's', weight: 1.1, price: 57500),
      ];
      pr = setProgress(s, more, products);
      expect(pr.leftKg, closeTo(-0.1, 1e-9), reason: 'перебор 100 г');
      expect(pr.off(), isFalse);
      // Заказано на сумму — сколько осталось в рублях.
      final rubSet = line(
        's',
        'set',
        qty: 3000,
        unit: OrderedUnit.rub,
        price: 92000,
      );
      pr = setProgress(rubSet, parts, products);
      expect(pr.leftKg, isNull);
      expect(pr.leftAmount, 300000 - 184000);
      // Пустые части — 0 кг.
      pr = setProgress(s, [line('p9', 'rib', parent: 's')], products);
      expect(pr.collected, 0);
      expect(pr.leftKg, 3);
      // Часть ещё не на весах — недобор пока не ошибка (перебор — сразу).
      final collecting = [...parts, line('p9', 'rib', parent: 's')];
      pr = setProgress(s, collecting, products);
      expect(pr.complete, isFalse);
      expect(pr.off(), isFalse, reason: 'набор ещё собирается');
      expect(weightOff(s, parts: collecting), isFalse);
      expect(weightOff(s, parts: parts), isTrue, reason: 'собран, недобор');
    });

    test('отклонение набора — по сумме частей', () {
      final s = line('s', 'set', qty: 1.5, unit: OrderedUnit.kg);
      expect(weightDeviation(s, parts: parts), closeTo(0.3333, 1e-3));
    });
  });

  test('проверки', () {
    const o = SaleOrder(id: 'o', batchId: 'b', customerId: '', number: 1);
    expect(orderProblem(o), isNotNull);
    expect(orderProblem(o.copyWith(customerId: 'c')), isNull);
    expect(
      orderLineProblem(line('1', 'vyr', pricing: LinePricing.fixed)),
      isNotNull,
    );
    expect(
      salesRowProblem('sale_order_lines', {'pricing': 'manual', 'price': null}),
      isNotNull,
    );
  });
}
