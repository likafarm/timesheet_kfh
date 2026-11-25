import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

/// Выдачи (11.5): сборочный лист, очередь взвешивания, итог.
void main() {
  const tenderloin = Product(id: 'vyr', groupId: 'g2', name: 'Вырезка');
  const head = Product(
    id: 'head',
    groupId: 'g1',
    name: 'Голова',
    unit: ProductUnit.pcs,
  );
  const set = Product(id: 'set', groupId: 'g2', name: 'Набор', sortOrder: 1);
  const rib = Product(id: 'rib', groupId: 'g2', name: 'Ребро', sortOrder: 2);
  final products = {
    for (final p in [tenderloin, head, set, rib]) p.id: p,
  };
  const groups = [
    ProductGroup(id: 'g1', name: 'Субпродукты', sortOrder: 0),
    ProductGroup(id: 'g2', name: 'Говядина', sortOrder: 1),
  ];
  final batch = SaleBatch(id: 'b', day: DateTime(2026, 6, 27));
  const o1 = SaleOrder(id: 'o1', batchId: 'b', customerId: 'c1', number: 1);
  const o2 = SaleOrder(id: 'o2', batchId: 'b', customerId: 'c2', number: 2);
  const o3 = SaleOrder(
    id: 'o3',
    batchId: 'b',
    customerId: 'c3',
    number: 3,
    status: OrderStatus.cancelled,
  );
  const o4 = SaleOrder(
    id: 'o4',
    batchId: 'b',
    customerId: 'c4',
    number: 4,
    kind: OrderKind.free,
  );

  final lines = [
    // o1: вырезка 2 кг (взвешено 2,2) и набор 3 кг из двух частей ребра.
    const SaleOrderLine(
      id: 'l1',
      orderId: 'o1',
      productId: 'vyr',
      orderedQty: 2,
      orderedUnit: OrderedUnit.kg,
      weight: 2.2,
      price: 100000,
      state: LineState.assembled,
    ),
    const SaleOrderLine(
      id: 'l2',
      orderId: 'o1',
      productId: 'set',
      sortOrder: 1,
      orderedQty: 3,
      orderedUnit: OrderedUnit.kg,
      price: 80000,
    ),
    const SaleOrderLine(
      id: 'l2a',
      orderId: 'o1',
      parentId: 'l2',
      productId: 'rib',
      weight: 1.5,
      state: LineState.assembled,
    ),
    const SaleOrderLine(
      id: 'l2b',
      orderId: 'o1',
      parentId: 'l2',
      productId: 'rib',
    ),
    // o2: голова 1 шт — не хватило; вырезка текстом.
    const SaleOrderLine(
      id: 'l3',
      orderId: 'o2',
      productId: 'head',
      orderedQty: 1,
      orderedUnit: OrderedUnit.pcs,
      state: LineState.missing,
      note: 'не хватило',
    ),
    const SaleOrderLine(
      id: 'l4',
      orderId: 'o2',
      productId: 'vyr',
      sortOrder: 1,
      orderedText: 'кусок побольше',
    ),
    // o3 отменён — в выдачу не входит.
    const SaleOrderLine(
      id: 'l5',
      orderId: 'o3',
      productId: 'vyr',
      orderedQty: 5,
      orderedUnit: OrderedUnit.kg,
    ),
    // o4 без оплаты: вырезка 1 кг, выдано 1 кг.
    const SaleOrderLine(
      id: 'l6',
      orderId: 'o4',
      productId: 'vyr',
      orderedQty: 1,
      orderedUnit: OrderedUnit.kg,
      weight: 1,
      price: 100000,
      state: LineState.assembled,
    ),
  ];
  final orders = batchOrders([o3, o2, o4, o1], batch.id);

  test('в выдачу — заказы без отменённых, по номеру', () {
    expect(orders.map((o) => o.id), ['o1', 'o2', 'o4']);
  });

  test('очередь взвешивания: части набора вместо набора', () {
    final queue = weighingQueue(batchEntries(orders, lines));
    expect(queue.map((e) => e.line.id), ['l1', 'l2a', 'l2b', 'l3', 'l4', 'l6']);
    expect(queue[1].parent?.id, 'l2');
    expect(queue.where((e) => !e.done).map((e) => e.line.id), ['l2b', 'l4']);
  });

  test('сборочный лист: товары по порядку прайса, кому сколько', () {
    final items = pickList(
      batchEntries(orders, lines),
      products,
      groups: groups,
    );
    expect(items.map((i) => i.productId), ['head', 'vyr', 'set', 'rib']);
    final vyr = items[1];
    expect(vyr.entries.map((e) => e.order.id), ['o1', 'o2', 'o4']);
    expect(vyr.orderedKg, 3);
    expect(vyr.orderedText, 1);
    expect(vyr.factKg, closeTo(3.2, 1e-9));
    expect(vyr.open, 1);
    final headItem = items[0];
    expect(headItem.orderedPcs, 1);
    expect(headItem.missing, 1);
    final setItem = items[2];
    expect(setItem.orderedKg, 3);
    expect(setItem.open, 1, reason: 'набор ещё собирается');
    expect(items[3].factKg, 1.5);
  });

  test('итог выдачи: кг, к оплате, без оплаты, нехватка', () {
    final s = batchSummary(orders, lines, products);
    expect(s.orders, 3);
    expect(s.byStatus[OrderStatus.accepted], 3);
    expect(s.toWeigh, 6);
    expect(s.open, 2);
    expect(s.missing, 1);
    expect(s.orderedKg, 6, reason: 'вырезка 2 + набор 3 + без оплаты 1');
    expect(s.factKg, closeTo(3.2, 1e-9), reason: 'набор ещё не собран');
    expect(s.freeKg, 1);
    expect(s.final_, isFalse);
    expect(s.shortages.single.line.id, 'l3');
    // К оплате — только продажи: вырезка 2,2 × 1000 + набор ≈ 3 × 800.
    expect(s.due, 220000 + 240000);
  });

  test('заказ собран, когда ни одной строки не осталось', () {
    expect(orderAssembled(lines.where((l) => l.orderId == 'o4')), isTrue);
    expect(orderAssembled(lines.where((l) => l.orderId == 'o1')), isFalse);
    expect(orderAssembled(const []), isFalse);
  });
}
