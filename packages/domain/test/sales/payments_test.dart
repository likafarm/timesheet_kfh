import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

/// Оплата заказов (11.6): ссылка на заказ, состояние оплаты, долг и аванс
/// покупателя, статья по умолчанию, права продавца.
void main() {
  FinOperation op(
    String id,
    int amount, {
    String order = 'o1',
    OperationType type = OperationType.income,
    DateTime? date,
  }) => FinOperation(
    id: id,
    date: date ?? DateTime(2026, 6, 27),
    type: type,
    amount: amount,
    accountId: 'cash',
    categoryId: 'meat',
    sourceRef: orderSourceRef(order),
  );

  const weighed = OrderTotals(
    fact: 500000,
    estimate: 500000,
    complete: true,
    unknown: 0,
    weight: 5,
  );
  const preliminary = OrderTotals(
    fact: 0,
    estimate: 400000,
    complete: false,
    unknown: 0,
    weight: 0,
  );
  const order = SaleOrder(id: 'o1', batchId: 'b', customerId: 'c', number: 1);

  test('ссылка на заказ', () {
    expect(orderSourceRef('abc'), 'order:abc');
    expect(orderIdOfRef('order:abc'), 'abc');
    expect(orderIdOfRef('plan:x:2026-01-01'), isNull);
    expect(orderIdOfRef(null), isNull);
  });

  test('оплаты по заказам: возврат — минусом, по дате', () {
    final map = paymentsByOrder([
      op('p2', 100000, date: DateTime(2026, 6, 28)),
      op('p1', 300000),
      op('r1', 50000, type: OperationType.expense),
      op('x', 1000, order: 'o2'),
      FinOperation(
        id: 'other',
        date: DateTime(2026, 6, 1),
        type: OperationType.income,
        amount: 1,
        accountId: 'cash',
      ),
    ]);
    expect(map.keys, unorderedEquals(['o1', 'o2']));
    expect(map['o1']!.first.id, 'p1');
    expect(map['o1']!.fold<int>(0, (s, o) => s + paymentAmount(o)), 350000);
  });

  test('состояние оплаты заказа', () {
    expect(orderPayment(order, weighed, []).state, PaymentState.unpaid);
    final part = orderPayment(order, weighed, [op('p', 200000)]);
    expect(part.state, PaymentState.partial);
    expect(part.left, 300000);
    expect(
      orderPayment(order, weighed, [op('p', 500000)]).state,
      PaymentState.paid,
    );
    final over = orderPayment(order, weighed, [op('p', 600000)]);
    expect(over.state, PaymentState.overpaid);
    expect(over.left, -100000);
    // До взвешивания предоплата больше предварительной — ещё не переплата.
    expect(
      orderPayment(order, preliminary, [op('p', 450000)]).state,
      PaymentState.paid,
    );
    // Без оплаты — денег не ждём.
    final free = orderPayment(
      order.copyWith(kind: OrderKind.free),
      weighed,
      [],
    );
    expect(free.state, PaymentState.none);
    expect(free.due, 0);
  });

  test('долг и аванс покупателя — по всем заказам', () {
    final orders = [
      order.copyWith(status: OrderStatus.issued),
      const SaleOrder(
        id: 'o2',
        batchId: 'b',
        customerId: 'c',
        number: 2,
        status: OrderStatus.issued,
      ),
      const SaleOrder(id: 'o3', batchId: 'b2', customerId: 'c', number: 1),
    ];
    final payments = paymentsByOrder([
      op('p1', 500000),
      op('p2', 300000, order: 'o2'),
      op('p3', 100000, order: 'o3'), // предоплата невыданного
    ]);
    final b = customerBalance(orders, (_) => weighed, payments);
    expect(b.charged, 1000000, reason: 'только выданные');
    expect(b.paid, 900000);
    expect(b.debt, 100000);
    expect(b.advance, 0);
    final more = paymentsByOrder([
      op('p1', 700000),
      op('p2', 500000, order: 'o2'),
    ]);
    expect(customerBalance(orders, (_) => weighed, more).advance, 200000);
  });

  test('статья и направление по умолчанию', () {
    const cats = [
      FinCategory(
        id: 'c1',
        type: CategoryType.income,
        group: 'Реализация',
        name: 'Реализация молока',
      ),
      FinCategory(
        id: 'c2',
        type: CategoryType.income,
        group: 'Реализация',
        name: 'Реализация мяса',
        directionId: 'd-meat',
      ),
      FinCategory(
        id: 'c3',
        type: CategoryType.expense,
        group: 'Прочее',
        name: 'Возврат покупателю',
      ),
    ];
    expect(defaultSaleCategory(cats)?.id, 'c2');
    expect(defaultRefundCategory(cats)?.id, 'c3');
    expect(saleDirectionId(cats[1], const []), 'd-meat');
    expect(
      saleDirectionId(cats[0], const [
        FinDirection(id: 'd1', name: 'Растениеводство'),
        FinDirection(id: 'd2', name: 'Реализация'),
      ]),
      'd2',
    );
    expect(defaultSaleCategory([cats[2]]), isNull);
  });

  test('продавец: только свои оплаты по заказам', () {
    String? check({
      bool exists = false,
      String? existingCreatedBy,
      String type = 'income',
      String? createdBy = 'u',
      String? sourceRef = 'order:o1',
    }) => salesOperationProblem(
      userUuid: 'u',
      exists: exists,
      existingCreatedBy: existingCreatedBy,
      type: type,
      createdBy: createdBy,
      sourceRef: sourceRef,
    );
    expect(check(), isNull);
    expect(check(type: 'expense'), isNull, reason: 'возврат');
    expect(check(type: 'transfer'), isNotNull);
    expect(check(sourceRef: null), isNotNull);
    expect(check(createdBy: 'other'), isNotNull);
    expect(check(exists: true, existingCreatedBy: 'buh'), isNotNull);
    expect(salesSeesOperation('order:o1', 'buh', 'u'), isTrue);
    expect(salesSeesOperation(null, 'u', 'u'), isTrue);
    expect(salesSeesOperation(null, 'buh', 'u'), isFalse);
  });
}
