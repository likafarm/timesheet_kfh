// packages/domain/lib/src/sales/reports.dart
//
// Отчёты по продажам (этап 11.8): продажи по товарам и месяцам (кг или
// штуки, рубли, средняя цена), по выдачам (продано, без оплаты, себе,
// выручка, оплачено, долг), «заказано против выданного» (отклонения веса,
// нехватка) и покупатели (сколько раз и на сколько, когда последний раз,
// долг или аванс). Продажа — выданный заказ; отменённые и невыданные не
// входят. Деньги — копейки; выручка — только заказы «Продажа», «Без
// оплаты» и «Себе» — килограммы и стоимость по цене строки.

import '../finance/models.dart';
import '../utils/date_utils.dart';
import 'orders.dart';
import 'payments.dart';
import 'price_list.dart';

/// Всё, из чего строятся отчёты.
class SalesData {
  final Map<String, SaleBatch> batches;
  final List<SaleOrder> orders;
  final List<SaleOrderLine> lines;
  final Map<String, Product> products;

  /// Оплаты по заказам ([paymentsByOrder]).
  final Map<String, List<FinOperation>> payments;

  SalesData({
    required Iterable<SaleBatch> batches,
    required this.orders,
    required this.lines,
    required this.products,
    this.payments = const {},
  }) : batches = {for (final b in batches) b.id: b};

  late final Map<String, List<SaleOrderLine>> _byOrder = () {
    final m = <String, List<SaleOrderLine>>{};
    for (final l in lines) {
      (m[l.orderId] ??= []).add(l);
    }
    return m;
  }();

  List<SaleOrderLine> linesOf(String orderId) => _byOrder[orderId] ?? const [];

  OrderTotals totalsOf(String orderId) =>
      orderTotals(linesOf(orderId), orderId, products);

  /// День заказа — день его выдачи; null — выдача не найдена.
  DateTime? dayOf(SaleOrder o) => batches[o.batchId]?.day;
}

/// Период отчёта по дням выдачи, включительно; null — без границы.
class SalesPeriod {
  final DateTime? from;
  final DateTime? to;
  const SalesPeriod({this.from, this.to});

  /// Весь год [year].
  SalesPeriod.year(int year)
    : from = DateTime(year),
      to = DateTime(year, 12, 31);

  /// Месяц.
  SalesPeriod.month(int year, int month)
    : from = DateTime(year, month),
      to = DateTime(year, month + 1, 0);

  bool contains(DateTime day) {
    final d = calendarDay(day);
    return (from == null || !d.isBefore(calendarDay(from!))) &&
        (to == null || !d.isAfter(calendarDay(to!)));
  }
}

/// Строка заказа, ушедшая покупателю: товар, количество и сумма.
class _Sold {
  final SaleOrder order;
  final SaleOrderLine line;
  final DateTime day;

  /// Кг (товары на вес и наборы) или штуки; null — вес не записан.
  final double? qty;
  final bool byWeight;

  /// Сумма по факту; null — не посчитать.
  final int? amount;
  const _Sold(
    this.order,
    this.line,
    this.day,
    this.qty,
    this.byWeight,
    this.amount,
  );
}

/// Выданные строки заказов периода (верхние строки: набор — целиком).
List<_Sold> _sold(SalesData data, SalesPeriod period) {
  final result = <_Sold>[];
  for (final o in data.orders) {
    if (o.status != OrderStatus.issued) continue;
    final day = data.dayOf(o);
    if (day == null || !period.contains(day)) continue;
    final (:top, :parts) = orderLines(data.linesOf(o.id), o.id);
    for (final l in top) {
      if (l.state == LineState.missing) continue;
      final ps = parts[l.id] ?? const <SaleOrderLine>[];
      final product = data.products[l.productId];
      final byWeight =
          ps.isNotEmpty || (product?.unit ?? ProductUnit.kg) == ProductUnit.kg;
      result.add(
        _Sold(
          o,
          l,
          calendarDay(day),
          factQty(l, product, parts: ps),
          byWeight,
          lineAmount(l, data.products, parts: ps),
        ),
      );
    }
  }
  return result;
}

// ------------------------------------------------------------ по товарам

/// Количество и деньги за месяц (или за период).
class SalesCell {
  double qty = 0;
  int amount = 0;

  /// Количество строк, у которых есть и количество, и сумма — для средней
  /// цены (строки без веса из истории её не искажают).
  double pricedQty = 0;
  int pricedAmount = 0;

  /// Средняя цена за кг (штуку), копейки; null — не посчитать.
  int? get averagePrice =>
      pricedQty <= 0 ? null : (pricedAmount / pricedQty).round();
}

/// Товар в отчёте продаж.
class ProductSales {
  final String productId;

  /// Кг (товар на вес или набор), иначе — штуки.
  final bool byWeight;

  /// Проданное («Продажа») — итог и по месяцам `(год, месяц)`.
  final SalesCell total = SalesCell();
  final Map<(int, int), SalesCell> months = {};

  /// Без оплаты и себе — количество и стоимость по цене строки.
  double freeQty = 0;
  int freeValue = 0;
  double ownQty = 0;
  int ownValue = 0;

  /// Строки без записанного веса (перенесённые из Excel).
  int noQty = 0;
  int orders = 0;

  ProductSales(this.productId, {required this.byWeight});
}

class ProductSalesReport {
  final List<ProductSales> rows;

  /// Месяцы с продажами, по порядку.
  final List<(int, int)> months;
  final SalesCell total;
  final Map<(int, int), SalesCell> monthTotals;
  final int freeValue;
  final int ownValue;
  const ProductSalesReport({
    required this.rows,
    required this.months,
    required this.total,
    required this.monthTotals,
    required this.freeValue,
    required this.ownValue,
  });
}

/// Продажи по товарам и месяцам за [period]; товары — по порядку прайса
/// ([groupOrder] — порядок групп), затем по названию.
ProductSalesReport productSales(
  SalesData data,
  SalesPeriod period, {
  Map<String, int> groupOrder = const {},
}) {
  final rows = <String, ProductSales>{};
  final orderSets = <String, Set<String>>{};
  final total = SalesCell();
  final monthTotals = <(int, int), SalesCell>{};
  var freeValue = 0, ownValue = 0;
  void add(SalesCell c, _Sold s) {
    c.qty += s.qty ?? 0;
    c.amount += s.amount ?? 0;
    if (s.qty != null && s.qty! > 0 && s.amount != null) {
      c.pricedQty += s.qty!;
      c.pricedAmount += s.amount!;
    }
  }

  for (final s in _sold(data, period)) {
    final r = rows[s.line.productId] ??= ProductSales(
      s.line.productId,
      byWeight: s.byWeight,
    );
    (orderSets[s.line.productId] ??= {}).add(s.order.id);
    if (s.qty == null) r.noQty++;
    switch (s.order.kind) {
      case OrderKind.sale:
        final m = (s.day.year, s.day.month);
        add(r.total, s);
        add(r.months[m] ??= SalesCell(), s);
        add(total, s);
        add(monthTotals[m] ??= SalesCell(), s);
      case OrderKind.free:
        r.freeQty += s.qty ?? 0;
        r.freeValue += s.amount ?? 0;
        freeValue += s.amount ?? 0;
      case OrderKind.own:
        r.ownQty += s.qty ?? 0;
        r.ownValue += s.amount ?? 0;
        ownValue += s.amount ?? 0;
    }
  }
  for (final e in orderSets.entries) {
    rows[e.key]!.orders = e.value.length;
  }
  int key(Product? p) => groupOrder[p?.groupId] ?? 1 << 30;
  final list = rows.values.toList()
    ..sort((a, b) {
      final pa = data.products[a.productId], pb = data.products[b.productId];
      final g = key(pa).compareTo(key(pb));
      if (g != 0) return g;
      final s = (pa?.sortOrder ?? 0).compareTo(pb?.sortOrder ?? 0);
      if (s != 0) return s;
      return (pa?.name ?? '').compareTo(pb?.name ?? '');
    });
  final months = monthTotals.keys.toList()
    ..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  return ProductSalesReport(
    rows: list,
    months: months,
    total: total,
    monthTotals: monthTotals,
    freeValue: freeValue,
    ownValue: ownValue,
  );
}

// ------------------------------------------------------------ по выдачам

/// Выдача в отчёте.
class BatchSales {
  final SaleBatch batch;
  int orders = 0;
  double saleKg = 0;
  int saleAmount = 0;
  double freeKg = 0;
  double ownKg = 0;

  /// Стоимость «без оплаты» и «себе» по цене строк.
  int freeValue = 0;
  int paid = 0;

  /// Недоплачено по выданным заказам.
  int debt = 0;
  BatchSales(this.batch);
}

/// Выдачи периода (по дню выдачи, новые сверху).
List<BatchSales> batchSales(SalesData data, SalesPeriod period) {
  final rows = <String, BatchSales>{};
  for (final s in _sold(data, period)) {
    final b = rows[s.order.batchId] ??= BatchSales(
      data.batches[s.order.batchId]!,
    );
    final kg = s.byWeight ? (s.qty ?? 0) : 0.0;
    switch (s.order.kind) {
      case OrderKind.sale:
        b.saleKg += kg;
        b.saleAmount += s.amount ?? 0;
      case OrderKind.free:
        b.freeKg += kg;
        b.freeValue += s.amount ?? 0;
      case OrderKind.own:
        b.ownKg += kg;
        b.freeValue += s.amount ?? 0;
    }
  }
  for (final o in data.orders) {
    final b = rows[o.batchId];
    if (b == null || o.status != OrderStatus.issued) continue;
    b.orders++;
    final pay = orderPayment(o, data.totalsOf(o.id), data.payments[o.id] ?? []);
    b.paid += pay.paid;
    if (o.kind == OrderKind.sale &&
        (pay.state == PaymentState.unpaid ||
            pay.state == PaymentState.partial)) {
      b.debt += pay.left;
    }
  }
  return rows.values.toList()
    ..sort((a, b) => b.batch.day.compareTo(a.batch.day));
}

// ------------------------------------------- заказано против выданного

/// Товар: заказано в кг против выданного и нехватка.
class OrderedVsIssued {
  final String productId;

  /// Строки, заказанные в килограммах и взвешенные.
  int lines = 0;
  double orderedKg = 0;
  double factKg = 0;

  /// Отклонение веса сверх допуска: больше и меньше заказанного.
  int over = 0;
  int under = 0;

  /// Не выдано (не хватило): строк и сколько кг из них заказывали.
  int missing = 0;
  double missingKg = 0;
  OrderedVsIssued(this.productId);

  /// Выдано к заказанному: +0.08 — на 8 % больше; null — нечего сравнить.
  double? get deviation => orderedKg <= 0 ? null : factKg / orderedKg - 1;
}

/// Заказано против выданного по товарам за [period] (выданные заказы);
/// [tolerance] — допуск отклонения (0.15 — 15 %). По убыванию нехватки,
/// затем — заказанного.
List<OrderedVsIssued> orderedVsIssued(
  SalesData data,
  SalesPeriod period, {
  double tolerance = 0.15,
}) {
  final rows = <String, OrderedVsIssued>{};
  for (final o in data.orders) {
    if (o.status != OrderStatus.issued) continue;
    final day = data.dayOf(o);
    if (day == null || !period.contains(day)) continue;
    final (:top, :parts) = orderLines(data.linesOf(o.id), o.id);
    for (final l in top) {
      final r = rows[l.productId] ??= OrderedVsIssued(l.productId);
      final kgOrdered = l.orderedUnit == OrderedUnit.kg ? l.orderedQty : null;
      if (l.state == LineState.missing) {
        r.missing++;
        r.missingKg += kgOrdered ?? 0;
        continue;
      }
      final ps = parts[l.id] ?? const <SaleOrderLine>[];
      final fact = factQty(l, data.products[l.productId], parts: ps);
      if (kgOrdered == null || kgOrdered <= 0 || fact == null) continue;
      r.lines++;
      r.orderedKg += kgOrdered;
      r.factKg += fact;
      final dev = fact / kgOrdered - 1;
      if (dev > tolerance) r.over++;
      if (dev < -tolerance) r.under++;
    }
  }
  final list = [
    for (final r in rows.values)
      if (r.lines > 0 || r.missing > 0) r,
  ];
  list.sort((a, b) {
    final m = b.missing.compareTo(a.missing);
    return m != 0 ? m : b.orderedKg.compareTo(a.orderedKg);
  });
  return list;
}

// ------------------------------------------------------------ покупатели

/// Покупатель в отчёте.
class CustomerSales {
  final String customerId;

  /// Выданных заказов «Продажа» за период и их сумма.
  int orders = 0;
  int amount = 0;
  DateTime? first;

  /// Последний заказ (любой, кроме отменённого) — за всё время.
  DateTime? last;

  /// Долг (минус) или аванс (плюс) по всем заказам.
  int balance = 0;
  CustomerSales(this.customerId);

  int? get averageCheck => orders == 0 ? null : (amount / orders).round();

  /// Дней с последнего заказа на [today]; null — заказов нет.
  int? daysSince(DateTime today) =>
      last == null ? null : calendarDay(today).difference(last!).inDays;
}

/// Покупатели: частота и сумма за [period], последний заказ и долг —
/// за всё время. По убыванию суммы.
List<CustomerSales> customerSales(SalesData data, SalesPeriod period) {
  final rows = <String, CustomerSales>{};
  final byCustomer = <String, List<SaleOrder>>{};
  for (final o in data.orders) {
    if (o.status == OrderStatus.cancelled) continue;
    (byCustomer[o.customerId] ??= []).add(o);
    final day = data.dayOf(o);
    if (day == null) continue;
    final r = rows[o.customerId] ??= CustomerSales(o.customerId);
    final d = calendarDay(day);
    if (r.last == null || d.isAfter(r.last!)) r.last = d;
    if (o.status != OrderStatus.issued ||
        o.kind != OrderKind.sale ||
        !period.contains(d)) {
      continue;
    }
    r.orders++;
    r.amount += data.totalsOf(o.id).fact;
    if (r.first == null || d.isBefore(r.first!)) r.first = d;
  }
  for (final r in rows.values) {
    r.balance = customerBalance(
      byCustomer[r.customerId] ?? const [],
      data.totalsOf,
      data.payments,
    ).balance;
  }
  return rows.values.toList()..sort((a, b) {
    final s = b.amount.compareTo(a.amount);
    return s != 0
        ? s
        : (b.last ?? DateTime(0)).compareTo(a.last ?? DateTime(0));
  });
}

// ------------------------------------------------------ главный экран

/// Сводка продаж для главного экрана.
class SalesDashboard {
  /// Ближайшая выдача с сегодняшнего дня; null — не назначена.
  final SaleBatch? nextBatch;
  final int nextOrders;

  /// Несобранные заказы («Принят») — по всем выдачам, в том числе прошедшим.
  final int unassembled;

  /// Из них — у прошедших выдач (забытые).
  final int overdue;

  /// Долг покупателей по выданным заказам и сколько их.
  final int debt;
  final int debtors;

  const SalesDashboard({
    required this.nextBatch,
    required this.nextOrders,
    required this.unassembled,
    required this.overdue,
    required this.debt,
    required this.debtors,
  });

  bool get isEmpty => nextBatch == null && unassembled == 0 && debt == 0;
}

SalesDashboard buildSalesDashboard(SalesData data, DateTime today) {
  final day = calendarDay(today);
  SaleBatch? next;
  for (final b in data.batches.values) {
    final last = calendarDay(b.dayTo ?? b.day);
    if (last.isBefore(day)) continue;
    if (next == null || b.day.isBefore(next.day)) next = b;
  }
  var nextOrders = 0, unassembled = 0, overdue = 0;
  final debtByCustomer = <String, int>{};
  for (final o in data.orders) {
    if (o.status == OrderStatus.cancelled) continue;
    if (next != null && o.batchId == next.id) nextOrders++;
    if (o.status == OrderStatus.accepted) {
      unassembled++;
      final b = data.batches[o.batchId];
      if (b != null && calendarDay(b.dayTo ?? b.day).isBefore(day)) overdue++;
    }
  }
  final byCustomer = <String, List<SaleOrder>>{};
  for (final o in data.orders) {
    if (o.status == OrderStatus.cancelled) continue;
    (byCustomer[o.customerId] ??= []).add(o);
  }
  for (final e in byCustomer.entries) {
    final debt = customerBalance(e.value, data.totalsOf, data.payments).debt;
    if (debt > 0) debtByCustomer[e.key] = debt;
  }
  return SalesDashboard(
    nextBatch: next,
    nextOrders: nextOrders,
    unassembled: unassembled,
    overdue: overdue,
    debt: debtByCustomer.values.fold(0, (s, v) => s + v),
    debtors: debtByCustomer.length,
  );
}
