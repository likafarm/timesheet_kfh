// packages/domain/lib/src/sales/batches.dart
//
// Выдача (этап 11.5): день забоя, к которому собираются заказы.
// Сборочный лист — что из каждого товара заказано и кому (бронь частей
// туши: голова, хвост, язык, печень); очередь взвешивания — строки
// заказов подряд, набор — по частям; итог — заказано / выдано / не
// выдано. Отменённые заказы в выдачу не входят.

import 'orders.dart';
import 'price_list.dart';

/// Строка заказа в выдаче: заказ, строка и (для набора) его части; для
/// части — строка набора [parent].
class BatchEntry {
  final SaleOrder order;
  final SaleOrderLine line;
  final List<SaleOrderLine> parts;
  final SaleOrderLine? parent;

  const BatchEntry({
    required this.order,
    required this.line,
    this.parts = const [],
    this.parent,
  });

  bool get isPart => parent != null;
  bool get isSet => parts.isNotEmpty;

  /// Взвешено (собрано) или снято.
  bool get done => line.state != LineState.open;
}

/// Товар в сборочном листе: кому и сколько заказано, сколько выдано.
class PickItem {
  final String productId;
  final List<BatchEntry> entries;

  /// Заказано: кг, штуки, «на сумму» (копейки) и строк без количества
  /// (только текстом).
  final double orderedKg;
  final int orderedPcs;
  final int orderedRub;
  final int orderedText;

  /// Фактически (по собранным строкам).
  final double factKg;
  final int factPcs;

  final int open;
  final int missing;

  const PickItem({
    required this.productId,
    required this.entries,
    required this.orderedKg,
    required this.orderedPcs,
    required this.orderedRub,
    required this.orderedText,
    required this.factKg,
    required this.factPcs,
    required this.open,
    required this.missing,
  });
}

/// Заказы выдачи [batchId] без отменённых, по номеру.
List<SaleOrder> batchOrders(Iterable<SaleOrder> orders, String batchId) => [
  for (final o in orders)
    if (o.batchId == batchId && o.status != OrderStatus.cancelled) o,
]..sort((a, b) => a.number.compareTo(b.number));

/// Все строки выдачи по порядку заказов: верхние строки, за набором —
/// его части.
List<BatchEntry> batchEntries(
  List<SaleOrder> orders,
  Iterable<SaleOrderLine> lines,
) {
  final byOrder = <String, List<SaleOrderLine>>{};
  for (final l in lines) {
    (byOrder[l.orderId] ??= []).add(l);
  }
  final result = <BatchEntry>[];
  for (final o in orders) {
    final (:top, :parts) = orderLines(byOrder[o.id] ?? const [], o.id);
    for (final l in top) {
      final ps = parts[l.id] ?? const <SaleOrderLine>[];
      result.add(BatchEntry(order: o, line: l, parts: ps));
      for (final p in ps) {
        result.add(BatchEntry(order: o, line: p, parent: l));
      }
    }
  }
  return result;
}

/// Очередь взвешивания: то, что кладут на весы, — обычные строки и
/// части наборов; набор без частей взвешивается целиком.
List<BatchEntry> weighingQueue(List<BatchEntry> entries) => [
  for (final e in entries)
    if (!e.isSet) e,
];

/// Заказ собран: каждая строка взвешена или снята.
bool orderAssembled(Iterable<SaleOrderLine> lines) {
  var any = false;
  for (final l in lines) {
    any = true;
    if (l.state == LineState.open) return false;
  }
  return any;
}

bool _byWeight(Product? p) => (p?.unit ?? ProductUnit.kg) == ProductUnit.kg;

/// Сборочный лист: товары по порядку прайса ([groups] и порядок товара),
/// у каждого — строки заказов. Части набора — внутри строки набора
/// ([BatchEntry.parts]), сводка состава — [setComposition].
List<PickItem> pickList(
  List<BatchEntry> entries,
  Map<String, Product> products, {
  List<ProductGroup> groups = const [],
}) {
  final byProduct = <String, List<BatchEntry>>{};
  for (final e in entries) {
    // Части набора — внутри своего набора, не отдельным товаром.
    if (e.isPart) continue;
    (byProduct[e.line.productId] ??= []).add(e);
  }
  final items = [
    for (final MapEntry(key: id, value: list) in byProduct.entries)
      _pickItem(id, list, products),
  ];
  final groupOrder = {for (final g in groups) g.id: g.sortOrder};
  int key(String id) => groupOrder[products[id]?.groupId] ?? 1 << 20;
  items.sort((a, b) {
    final c = key(a.productId).compareTo(key(b.productId));
    if (c != 0) return c;
    final pa = products[a.productId], pb = products[b.productId];
    final s = (pa?.sortOrder ?? 0).compareTo(pb?.sortOrder ?? 0);
    return s != 0 ? s : (pa?.name ?? '').compareTo(pb?.name ?? '');
  });
  return items;
}

PickItem _pickItem(
  String productId,
  List<BatchEntry> entries,
  Map<String, Product> products,
) {
  var orderedKg = 0.0, factKg = 0.0;
  var orderedPcs = 0, orderedRub = 0, orderedText = 0, factPcs = 0;
  var open = 0, missing = 0;
  final product = products[productId];
  for (final e in entries) {
    final l = e.line;
    final qty = l.orderedQty;
    switch (l.orderedUnit) {
      case OrderedUnit.kg when qty != null:
        orderedKg += qty;
      case OrderedUnit.pcs when qty != null:
        orderedPcs += qty.round();
      case OrderedUnit.rub when qty != null:
        orderedRub += (qty * 100).round();
      default:
        orderedText++;
    }
    switch (l.state) {
      case LineState.open:
        open++;
      case LineState.missing:
        missing++;
      case LineState.assembled:
        final fact = factQty(l, product, parts: e.parts);
        if (e.isSet || _byWeight(product)) {
          factKg += fact ?? 0;
        } else {
          factPcs += fact?.round() ?? 0;
        }
        if (_byWeight(product) && !e.isSet && l.pieces != null) {
          factPcs += l.pieces!;
        }
    }
  }
  return PickItem(
    productId: productId,
    entries: entries,
    orderedKg: orderedKg,
    orderedPcs: orderedPcs,
    orderedRub: orderedRub,
    orderedText: orderedText,
    factKg: factKg,
    factPcs: factPcs,
    open: open,
    missing: missing,
  );
}

/// Итог выдачи.
class BatchSummary {
  final int orders;
  final Map<OrderStatus, int> byStatus;

  /// Строки к взвешиванию: всего, ещё не взвешено, снято (не выдано).
  final int toWeigh;
  final int open;
  final int missing;

  /// Заказано и выдано, кг (верхние строки: набор — целиком).
  final double orderedKg;
  final double factKg;

  /// К оплате по продажам (окончательно или предварительно), копейки;
  /// [final_] — все продажи взвешены.
  final int due;
  final bool final_;

  /// Без оплаты и себе: выдано, кг.
  final double freeKg;

  /// Снятые строки (кому не хватило).
  final List<BatchEntry> shortages;

  const BatchSummary({
    required this.orders,
    required this.byStatus,
    required this.toWeigh,
    required this.open,
    required this.missing,
    required this.orderedKg,
    required this.factKg,
    required this.due,
    required this.final_,
    required this.freeKg,
    required this.shortages,
  });
}

BatchSummary batchSummary(
  List<SaleOrder> orders,
  Iterable<SaleOrderLine> lines,
  Map<String, Product> products,
) {
  final entries = batchEntries(orders, lines);
  final queue = weighingQueue(entries);
  final byStatus = <OrderStatus, int>{};
  for (final o in orders) {
    byStatus[o.status] = (byStatus[o.status] ?? 0) + 1;
  }
  var orderedKg = 0.0, factKg = 0.0, freeKg = 0.0;
  for (final e in entries) {
    if (e.isPart) continue;
    final l = e.line;
    final product = products[l.productId];
    if (l.orderedUnit == OrderedUnit.kg && l.orderedQty != null) {
      orderedKg += l.orderedQty!;
    }
    if (l.state == LineState.assembled && (e.isSet || _byWeight(product))) {
      final fact = factQty(l, product, parts: e.parts) ?? 0;
      factKg += fact;
      if (e.order.kind != OrderKind.sale) freeKg += fact;
    }
  }
  final byOrder = <String, List<SaleOrderLine>>{};
  for (final l in lines) {
    (byOrder[l.orderId] ??= []).add(l);
  }
  var due = 0;
  var complete = true;
  for (final o in orders) {
    if (o.kind != OrderKind.sale) continue;
    final t = orderTotals(byOrder[o.id] ?? const [], o.id, products);
    due += t.due;
    complete = complete && t.complete;
  }
  return BatchSummary(
    orders: orders.length,
    byStatus: byStatus,
    toWeigh: queue.length,
    open: queue.where((e) => !e.done).length,
    missing: entries.where((e) => e.line.state == LineState.missing).length,
    orderedKg: orderedKg,
    factKg: factKg,
    due: due,
    final_: complete,
    freeKg: freeKg,
    shortages: [
      for (final e in entries)
        if (e.line.state == LineState.missing) e,
    ],
  );
}

/// Часть в составе наборов: товар, сколько строк и сколько собрано, кг.
class CompositionPart {
  final String productId;
  final int count;
  final double weight;
  final int open;
  const CompositionPart(this.productId, this.count, this.weight, this.open);
}

/// Состав наборов товара [item]: части по товару (сколько раз, собранный
/// вес, ещё не взвешено), по порядку первого появления.
List<CompositionPart> setComposition(PickItem item) {
  final order = <String>[];
  final count = <String, int>{}, open = <String, int>{};
  final weight = <String, double>{};
  for (final e in item.entries) {
    for (final p in e.parts) {
      if (!count.containsKey(p.productId)) order.add(p.productId);
      count[p.productId] = (count[p.productId] ?? 0) + 1;
      if (p.state == LineState.open) {
        open[p.productId] = (open[p.productId] ?? 0) + 1;
      }
      if (p.state == LineState.assembled) {
        weight[p.productId] = (weight[p.productId] ?? 0) + (p.weight ?? 0);
      }
    }
  }
  return [
    for (final id in order)
      CompositionPart(id, count[id]!, weight[id] ?? 0, open[id] ?? 0),
  ];
}
