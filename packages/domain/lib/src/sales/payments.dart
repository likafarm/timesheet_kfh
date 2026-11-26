// packages/domain/lib/src/sales/payments.dart
//
// Оплата заказов (этап 11.6, решения владельца 2026-11-24): деньги за
// заказ — обычная операция финансов (доход, статья «Реализация мяса»,
// контрагент — покупатель) со ссылкой `source_ref = order:<uuid>`; частями
// и предоплатой — несколько операций. Возврат покупателю — расход с той
// же ссылкой. В финансы — только реальные деньги: «без оплаты / себе» —
// без дохода. Переплата по умолчанию остаётся авансом покупателя
// (ответ 8): долг или аванс считается по всем его заказам.
//
// Специалист по продажам (11.2) в финансах: видит кошельки (без
// остатков), статьи, направления, контрагентов и оплаты заказов (все, с
// `order:`), пишет только свои доходы и возвраты по заказам и новых
// контрагентов. Те же правила проверяет сервер.

import '../finance/models.dart';
import 'orders.dart';

/// Ссылка операции финансов на заказ.
String orderSourceRef(String orderId) => 'order:$orderId';

const _orderRefPrefix = 'order:';

/// Заказ операции; null — операция не по заказу.
String? orderIdOfRef(String? sourceRef) =>
    sourceRef != null && sourceRef.startsWith(_orderRefPrefix)
    ? sourceRef.substring(_orderRefPrefix.length)
    : null;

/// Деньги по заказу, копейки: доход — плюс, возврат (расход) — минус.
int paymentAmount(FinOperation op) => switch (op.type) {
  OperationType.income => op.amount,
  OperationType.expense => -op.amount,
  _ => 0,
};

/// Оплаты по заказам: заказ → его операции (по дате).
Map<String, List<FinOperation>> paymentsByOrder(Iterable<FinOperation> ops) {
  final result = <String, List<FinOperation>>{};
  for (final op in ops) {
    final id = orderIdOfRef(op.sourceRef);
    if (id == null) continue;
    (result[id] ??= []).add(op);
  }
  for (final list in result.values) {
    list.sort((a, b) => a.date.compareTo(b.date));
  }
  return result;
}

/// Оплата заказа.
enum PaymentState {
  none('Без оплаты'),

  /// Перенесён из Excel (11.7): деньги получены до программы, их нет в
  /// финансах — не долг.
  history('Оплачен до программы'),
  unpaid('Не оплачен'),
  partial('Оплачен частично'),
  paid('Оплачен'),
  overpaid('Переплата');

  const PaymentState(this.title);
  final String title;
}

/// Расчёт по заказу: к оплате (по факту или предварительно), оплачено,
/// разница.
class OrderPayment {
  /// К оплате, копейки (0 — «без оплаты / себе» и отменённый).
  final int due;

  /// [due] окончательна (всё взвешено).
  final bool dueFinal;

  /// Оплачено (за вычетом возвратов), копейки.
  final int paid;

  final PaymentState state;

  const OrderPayment({
    required this.due,
    required this.dueFinal,
    required this.paid,
    required this.state,
  });

  /// Осталось доплатить (плюс) или переплачено (минус), копейки.
  int get left => due - paid;
}

/// Расчёт по заказу [order] с итогами [totals] и оплатами [payments].
/// Переплата до взвешивания — не «переплата»: сумма ещё предварительная.
OrderPayment orderPayment(
  SaleOrder order,
  OrderTotals totals,
  Iterable<FinOperation> payments,
) {
  final paid = payments.fold<int>(0, (s, op) => s + paymentAmount(op));
  final charged =
      order.kind == OrderKind.sale && order.status != OrderStatus.cancelled;
  final due = charged ? totals.due : 0;
  final PaymentState state;
  if (order.fromHistory && paid == 0) {
    state = charged ? PaymentState.history : PaymentState.none;
  } else if (!charged) {
    state = paid == 0 ? PaymentState.none : PaymentState.overpaid;
  } else if (paid <= 0) {
    state = PaymentState.unpaid;
  } else if (paid < due) {
    state = PaymentState.partial;
  } else if (paid > due && totals.complete) {
    state = PaymentState.overpaid;
  } else {
    state = PaymentState.paid;
  }
  return OrderPayment(
    due: due,
    dueFinal: totals.complete,
    paid: paid,
    state: state,
  );
}

/// Расчёт с покупателем по всем заказам: начислено — выданные заказы
/// (продажа, к оплате по факту), оплачено — все деньги по его заказам
/// (и предоплаты ещё не выданных). Плюс — аванс, минус — долг.
class CustomerBalance {
  final int charged;
  final int paid;
  const CustomerBalance(this.charged, this.paid);

  int get balance => paid - charged;
  int get debt => balance < 0 ? -balance : 0;
  int get advance => balance > 0 ? balance : 0;
}

CustomerBalance customerBalance(
  Iterable<SaleOrder> orders,
  OrderTotals Function(String orderId) totalsOf,
  Map<String, List<FinOperation>> payments,
) {
  var charged = 0, paid = 0;
  for (final o in orders) {
    for (final op in payments[o.id] ?? const <FinOperation>[]) {
      paid += paymentAmount(op);
    }
    // Перенесённый из Excel заказ оплачен до программы — если по нему не
    // вносили денег здесь.
    if (o.fromHistory && (payments[o.id] ?? const []).isEmpty) continue;
    if (o.kind == OrderKind.sale && o.status == OrderStatus.issued) {
      charged += totalsOf(o.id).due;
    }
  }
  return CustomerBalance(charged, paid);
}

/// Статья дохода для оплаты заказов: «Реализация мяса», иначе первая
/// статья дохода со словом «мяс» в названии; null — нет такой (выбрать
/// вручную).
FinCategory? defaultSaleCategory(Iterable<FinCategory> categories) {
  final income = [
    for (final c in categories)
      if (c.type == CategoryType.income && !c.hidden) c,
  ];
  String key(String s) => s.toLowerCase().replaceAll('ё', 'е').trim();
  for (final c in income) {
    if (key(c.name) == 'реализация мяса') return c;
  }
  for (final c in income) {
    if (key(c.name).contains('мяс')) return c;
  }
  return null;
}

/// Статья расхода для возврата покупателю: «Возврат покупателю», иначе
/// первая статья расхода со словом «возврат»; null — выбрать вручную.
FinCategory? defaultRefundCategory(Iterable<FinCategory> categories) {
  for (final c in categories) {
    if (c.type == CategoryType.expense &&
        !c.hidden &&
        c.name.toLowerCase().contains('возврат')) {
      return c;
    }
  }
  return null;
}

/// Направление операции: у статьи своё, иначе «Реализация» (по названию);
/// null — без направления.
String? saleDirectionId(FinCategory category, Iterable<FinDirection> all) {
  if (category.directionId != null) return category.directionId;
  for (final d in all) {
    if (d.name.toLowerCase().contains('реализ')) return d.id;
  }
  return null;
}

// --------------------------------------------- продавец в финансах

/// Таблицы финансов, которые получает специалист по продажам.
const salesFinanceReadable = {
  'fin_accounts',
  'fin_directions',
  'fin_category_groups',
  'fin_categories',
  'counterparties',
  'fin_operations',
};

/// Таблицы финансов, которые он пишет: оплаты по заказам и новые
/// контрагенты (покупатель заводится контрагентом при первой оплате).
const salesFinanceWritable = {'fin_operations', 'counterparties'};

/// Остатков кошельков продавец не видит.
const salesFinanceHidden = {
  'fin_accounts': {'opening_balance'},
};

/// Операция видна продавцу: оплата по заказу или введённая им.
bool salesSeesOperation(String? sourceRef, String? createdBy, String user) =>
    orderIdOfRef(sourceRef) != null || createdBy == user;

/// Почему продавец [userUuid] не может записать операцию; null — может.
String? salesOperationProblem({
  required String userUuid,
  required bool exists,
  String? existingCreatedBy,
  required String type,
  String? createdBy,
  String? sourceRef,
}) {
  if (exists && existingCreatedBy != userUuid) {
    return 'Продавец правит только свои оплаты — остальные исправляют '
        'бухгалтер и администратор';
  }
  if (createdBy != userUuid) {
    return 'Оплата записывается от имени продавца';
  }
  if (type != 'income' && type != 'expense') {
    return 'Продавец вносит только оплаты и возвраты по заказам';
  }
  if (orderIdOfRef(sourceRef) == null) {
    return 'Продавец вносит только оплаты по заказам';
  }
  return null;
}
