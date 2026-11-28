import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

/// Отчёты по продажам (11.8).
void main() {
  final products = {
    'vyr': const Product(id: 'vyr', groupId: 'g', name: 'Вырезка'),
    'set': const Product(id: 'set', groupId: 'g', name: 'Набор', sortOrder: 2),
    'rib': const Product(id: 'rib', groupId: 'g', name: 'Ребро', sortOrder: 3),
    'head': const Product(
      id: 'head',
      groupId: 'g',
      name: 'Голова',
      unit: ProductUnit.pcs,
      sortOrder: 1,
    ),
  };
  final batches = [
    SaleBatch(id: 'b1', day: DateTime(2026, 10, 10)),
    SaleBatch(id: 'b2', day: DateTime(2026, 11, 14)),
    SaleBatch(id: 'b3', day: DateTime(2026, 12, 5)),
  ];
  SaleOrderLine line(
    String id,
    String order,
    String product, {
    double? ordered,
    OrderedUnit unit = OrderedUnit.kg,
    double? weight,
    int? pieces,
    int price = 100000,
    LineState state = LineState.assembled,
    String? parent,
    LinePricing pricing = LinePricing.list,
  }) => SaleOrderLine(
    id: id,
    orderId: order,
    productId: product,
    parentId: parent,
    orderedQty: ordered,
    orderedUnit: unit,
    weight: weight,
    pieces: pieces,
    price: price,
    state: state,
    pricing: pricing,
  );

  final orders = [
    // Октябрь: Ольга — вырезка 2 кг → 2,4 кг (+20 %), голова 1 шт.
    const SaleOrder(
      id: 'o1',
      batchId: 'b1',
      customerId: 'olga',
      number: 1,
      status: OrderStatus.issued,
    ),
    // Ноябрь: Ольга — набор (ребро 3 кг), Пётр — вырезка не хватило.
    const SaleOrder(
      id: 'o2',
      batchId: 'b2',
      customerId: 'olga',
      number: 1,
      status: OrderStatus.issued,
    ),
    const SaleOrder(
      id: 'o3',
      batchId: 'b2',
      customerId: 'petr',
      number: 2,
      status: OrderStatus.issued,
    ),
    // Себе — 1 кг вырезки.
    const SaleOrder(
      id: 'o4',
      batchId: 'b2',
      customerId: 'farm',
      number: 3,
      kind: OrderKind.own,
      status: OrderStatus.issued,
    ),
    // Декабрь — ещё принят (не продажа), у Петра.
    const SaleOrder(id: 'o5', batchId: 'b3', customerId: 'petr', number: 1),
    const SaleOrder(
      id: 'o6',
      batchId: 'b2',
      customerId: 'petr',
      number: 4,
      status: OrderStatus.cancelled,
    ),
  ];
  final lines = [
    line('l1', 'o1', 'vyr', ordered: 2, weight: 2.4),
    line(
      'l2',
      'o1',
      'head',
      ordered: 1,
      unit: OrderedUnit.pcs,
      pieces: 1,
      price: 50000,
    ),
    line('l3', 'o2', 'set', ordered: 3, price: 90000),
    line('l4', 'o2', 'rib', weight: 3, price: 90000, parent: 'l3'),
    line('l5', 'o3', 'vyr', ordered: 1.5, state: LineState.missing),
    line('l6', 'o4', 'vyr', ordered: 1, weight: 1),
    line('l7', 'o5', 'vyr', ordered: 2, state: LineState.open),
    line('l8', 'o6', 'vyr', ordered: 5, weight: 5),
  ];
  final payments = {
    'o1': [
      FinOperation(
        id: 'p1',
        date: DateTime(2026, 10, 10),
        type: OperationType.income,
        amount: 290000,
        accountId: 'cash',
        sourceRef: 'order:o1',
      ),
    ],
  };
  final data = SalesData(
    batches: batches,
    orders: orders,
    lines: lines,
    products: products,
    payments: payments,
  );

  test('по товарам и месяцам: кг, рубли, средняя цена; себе — отдельно', () {
    final r = productSales(data, const SalesPeriod());
    expect(r.rows.map((x) => x.productId), ['vyr', 'head', 'set']);
    final vyr = r.rows.first;
    expect(vyr.byWeight, isTrue);
    expect(vyr.total.qty, closeTo(2.4, 1e-9));
    expect(vyr.total.amount, 240000);
    expect(vyr.total.averagePrice, 100000);
    expect(vyr.ownQty, 1);
    expect(vyr.ownValue, 100000);
    expect(vyr.orders, 2, reason: 'продажа и «себе»');
    final head = r.rows[1];
    expect(head.byWeight, isFalse);
    expect(head.total.qty, 1);
    final set = r.rows.last;
    expect(set.total.qty, 3, reason: 'набор — по весу частей');
    expect(set.total.amount, 270000);
    expect(r.months, [(2026, 10), (2026, 11)]);
    expect(r.monthTotals[(2026, 10)]!.amount, 290000);
    expect(r.total.amount, 560000);
    expect(r.ownValue, 100000);
    // Период — только ноябрь.
    final nov = productSales(data, SalesPeriod.month(2026, 11));
    expect(nov.total.amount, 270000);
    expect(nov.rows.map((x) => x.productId), ['vyr', 'set']);
  });

  test('по выдачам: продано, себе, оплачено и долг', () {
    final r = batchSales(data, const SalesPeriod());
    expect(r.map((b) => b.batch.id), ['b2', 'b1'], reason: 'новые сверху');
    final nov = r.first;
    expect(nov.orders, 3);
    expect(nov.saleKg, 3);
    expect(nov.saleAmount, 270000);
    expect(nov.ownKg, 1);
    expect(nov.freeValue, 100000);
    expect(nov.debt, 270000, reason: 'набор Ольги не оплачен');
    final oct = r.last;
    expect(oct.paid, 290000);
    expect(oct.debt, 0);
  });

  test('заказано против выданного: отклонение и нехватка', () {
    final r = orderedVsIssued(data, const SalesPeriod(), tolerance: 0.15);
    final vyr = r.firstWhere((x) => x.productId == 'vyr');
    expect(vyr.missing, 1);
    expect(vyr.missingKg, 1.5);
    expect(vyr.lines, 2);
    expect(vyr.orderedKg, 3);
    expect(vyr.factKg, closeTo(3.4, 1e-9));
    expect(vyr.over, 1, reason: '2,4 кг на 2 — +20 %');
    expect(r.first.productId, 'vyr', reason: 'с нехваткой — сверху');
    expect(r.any((x) => x.productId == 'head'), isFalse, reason: 'не в кг');
  });

  test('покупатели: сколько раз, сумма, последний заказ, долг', () {
    final r = customerSales(data, const SalesPeriod());
    final olga = r.firstWhere((x) => x.customerId == 'olga');
    expect(olga.orders, 2);
    expect(olga.amount, 560000);
    expect(olga.averageCheck, 280000);
    expect(olga.first, DateTime(2026, 10, 10));
    expect(olga.last, DateTime(2026, 11, 14));
    expect(olga.balance, -270000);
    expect(olga.daysSince(DateTime(2026, 11, 28)), 14);
    final petr = r.firstWhere((x) => x.customerId == 'petr');
    expect(petr.orders, 1, reason: 'выдан, хоть и пустой');
    expect(petr.last, DateTime(2026, 12, 5), reason: 'принятый — тоже');
    expect(r.first.customerId, 'olga', reason: 'по сумме');
  });

  test('главный экран: ближайшая выдача, несобранные, долги', () {
    final d = buildSalesDashboard(data, DateTime(2026, 11, 28));
    expect(d.nextBatch?.id, 'b3');
    expect(d.nextOrders, 1);
    expect(d.unassembled, 1);
    expect(d.overdue, 0);
    expect(d.debt, 270000);
    expect(d.debtors, 1);
    final later = buildSalesDashboard(data, DateTime(2026, 12, 10));
    expect(later.nextBatch, isNull);
    expect(later.overdue, 1, reason: 'выдача прошла, заказ не собран');
  });
}
