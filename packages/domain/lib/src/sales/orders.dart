// packages/domain/lib/src/sales/orders.dart
//
// Заказы мяса (этап 11.4, решения владельца 2026-11-24): заказ — покупатель
// и выдача (день забоя / выдачи), строки — товар прайса. В строке
// «заказано» и «фактически» хранятся раздельно: заказанное фактом не
// перезаписывается. Сумма к оплате — по факту; до взвешивания —
// предварительная (по заказанному). Набор — строка с частями (строки с
// `parentId`): вес набора — сумма частей; цена набора — по прайсу набора,
// по ценам частей, своя цена за кг или своя сумма за весь набор.
// Номер заказа — `ДДМ-N`: день и месяц выдачи и номер в выдаче.

import '../utils/date_utils.dart';
import 'price_list.dart';

/// Выдача: день забоя / выдачи, к которому собираются заказы. Диапазон
/// ([dayTo]) — для перенесённой истории («5–7.06.2025»).
class SaleBatch {
  final String id;
  final DateTime day;
  final DateTime? dayTo;
  final String? title;
  final String? notes;

  const SaleBatch({
    required this.id,
    required this.day,
    this.dayTo,
    this.title,
    this.notes,
  });

  SaleBatch copyWith({
    DateTime? Function()? dayTo,
    String? Function()? title,
    String? Function()? notes,
  }) => SaleBatch(
    id: id,
    day: day,
    dayTo: dayTo == null ? this.dayTo : dayTo(),
    title: title == null ? this.title : title(),
    notes: notes == null ? this.notes : notes(),
  );
}

/// Вид заказа.
enum OrderKind {
  sale('sale', 'Продажа'),
  free('free', 'Без оплаты'),
  own('own', 'Себе');

  const OrderKind(this.code, this.title);
  final String code;
  final String title;

  static OrderKind fromCode(String code) =>
      values.firstWhere((v) => v.code == code, orElse: () => sale);
}

/// Состояние заказа (оплата считается отдельно, по поступлениям — 11.6).
enum OrderStatus {
  accepted('new', 'Принят'),
  assembled('assembled', 'Собран'),
  issued('issued', 'Выдан'),
  cancelled('cancelled', 'Отменён');

  const OrderStatus(this.code, this.title);
  final String code;
  final String title;

  static OrderStatus fromCode(String code) =>
      values.firstWhere((v) => v.code == code, orElse: () => accepted);
}

enum Delivery {
  pickup('pickup', 'Самовывоз'),
  delivery('delivery', 'Доставка');

  const Delivery(this.code, this.title);
  final String code;
  final String title;

  static Delivery fromCode(String code) =>
      values.firstWhere((v) => v.code == code, orElse: () => pickup);
}

class SaleOrder {
  final String id;
  final String batchId;
  final String customerId;

  /// Номер в выдаче (N в `ДДМ-N`).
  final int number;
  final OrderKind kind;
  final Delivery delivery;

  /// Адрес доставки; null — из карточки покупателя.
  final String? address;
  final String? comment;
  final OrderStatus status;

  /// uuid пользователя сервера, принявшего заказ.
  final String? createdBy;

  const SaleOrder({
    required this.id,
    required this.batchId,
    required this.customerId,
    required this.number,
    this.kind = OrderKind.sale,
    this.delivery = Delivery.pickup,
    this.address,
    this.comment,
    this.status = OrderStatus.accepted,
    this.createdBy,
  });

  SaleOrder copyWith({
    String? batchId,
    String? customerId,
    int? number,
    OrderKind? kind,
    Delivery? delivery,
    String? Function()? address,
    String? Function()? comment,
    OrderStatus? status,
  }) => SaleOrder(
    id: id,
    batchId: batchId ?? this.batchId,
    customerId: customerId ?? this.customerId,
    number: number ?? this.number,
    kind: kind ?? this.kind,
    delivery: delivery ?? this.delivery,
    address: address == null ? this.address : address(),
    comment: comment == null ? this.comment : comment(),
    status: status ?? this.status,
    createdBy: createdBy,
  );
}

/// В чём заказано.
enum OrderedUnit {
  kg('kg', 'кг'),
  pcs('pcs', 'шт'),
  rub('rub', '₽');

  const OrderedUnit(this.code, this.title);
  final String code;
  final String title;

  static OrderedUnit? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// Как считается цена строки (для набора — все четыре, решение владельца
/// 2026-11-24; для обычного товара — по прайсу, своя цена за единицу или
/// своя сумма).
enum LinePricing {
  /// Факт × цена прайса на день выдачи.
  list('list', 'По прайсу'),

  /// Набор: Σ вес части × её цена по прайсу.
  parts('parts', 'По ценам частей'),

  /// Факт × своя цена за единицу ([SaleOrderLine.price]).
  manual('manual', 'Своя цена'),

  /// Своя сумма за всю строку ([SaleOrderLine.fixedAmount]).
  fixed('fixed', 'Своя сумма');

  const LinePricing(this.code, this.title);
  final String code;
  final String title;

  static LinePricing fromCode(String code) =>
      values.firstWhere((v) => v.code == code, orElse: () => list);
}

/// Состояние строки при сборке.
enum LineState {
  open('open', 'Не собрана'),
  assembled('assembled', 'Собрана'),
  missing('missing', 'Не выдана');

  const LineState(this.code, this.title);
  final String code;
  final String title;

  static LineState fromCode(String code) =>
      values.firstWhere((v) => v.code == code, orElse: () => open);
}

class SaleOrderLine {
  final String id;
  final String orderId;

  /// Часть набора: строка набора, к которой относится; null — обычная
  /// строка или сам набор.
  final String? parentId;
  final String productId;
  final int sortOrder;

  // --- заказано
  final double? orderedQty;
  final OrderedUnit? orderedUnit;

  /// Что просили, как сказал покупатель («кусок побольше», «4–5 шт»).
  final String? orderedText;

  // --- фактически
  final double? weight;
  final int? pieces;

  // --- цена
  final LinePricing pricing;

  /// Цена за единицу, копейки: по прайсу на день выдачи (записывается при
  /// добавлении строки) или своя ([LinePricing.manual]).
  final int? price;

  /// Своя сумма за строку, копейки ([LinePricing.fixed]).
  final int? fixedAmount;

  final LineState state;

  /// Почему не выдана / чем заменили.
  final String? note;

  /// Добавлено при сборке (не было в заказе).
  final bool added;

  const SaleOrderLine({
    required this.id,
    required this.orderId,
    required this.productId,
    this.parentId,
    this.sortOrder = 0,
    this.orderedQty,
    this.orderedUnit,
    this.orderedText,
    this.weight,
    this.pieces,
    this.pricing = LinePricing.list,
    this.price,
    this.fixedAmount,
    this.state = LineState.open,
    this.note,
    this.added = false,
  });

  bool get isPart => parentId != null;

  SaleOrderLine copyWith({
    String? productId,
    int? sortOrder,
    double? Function()? orderedQty,
    OrderedUnit? Function()? orderedUnit,
    String? Function()? orderedText,
    double? Function()? weight,
    int? Function()? pieces,
    LinePricing? pricing,
    int? Function()? price,
    int? Function()? fixedAmount,
    LineState? state,
    String? Function()? note,
    bool? added,
  }) => SaleOrderLine(
    id: id,
    orderId: orderId,
    parentId: parentId,
    productId: productId ?? this.productId,
    sortOrder: sortOrder ?? this.sortOrder,
    orderedQty: orderedQty == null ? this.orderedQty : orderedQty(),
    orderedUnit: orderedUnit == null ? this.orderedUnit : orderedUnit(),
    orderedText: orderedText == null ? this.orderedText : orderedText(),
    weight: weight == null ? this.weight : weight(),
    pieces: pieces == null ? this.pieces : pieces(),
    pricing: pricing ?? this.pricing,
    price: price == null ? this.price : price(),
    fixedAmount: fixedAmount == null ? this.fixedAmount : fixedAmount(),
    state: state ?? this.state,
    note: note == null ? this.note : note(),
    added: added ?? this.added,
  );
}

// ------------------------------------------------------------ номер заказа

/// `ДДМ` выдачи: день и месяц без нулей впереди (27.06 → «276»).
String batchCode(DateTime day) => '${day.day}${day.month}';

/// Номер заказа для человека: «276-15».
String orderLabel(SaleBatch batch, SaleOrder order) =>
    '${batchCode(batch.day)}-${order.number}';

/// Следующий номер в выдаче [batchId].
int nextOrderNumber(Iterable<SaleOrder> orders, String batchId) {
  var max = 0;
  for (final o in orders) {
    if (o.batchId == batchId && o.number > max) max = o.number;
  }
  return max + 1;
}

/// Выдача на день [day] (по дню начала); null — нет.
SaleBatch? batchOn(Iterable<SaleBatch> batches, DateTime day) {
  final d = calendarDay(day);
  for (final b in batches) {
    if (calendarDay(b.day) == d) return b;
  }
  return null;
}

// ----------------------------------------------------------------- суммы

/// Факт строки в единицах товара: кг — вес, остальное — штуки. Набор с
/// частями — сумма весов частей. null — ещё не взвешено.
double? factQty(
  SaleOrderLine line,
  Product? product, {
  List<SaleOrderLine> parts = const [],
}) {
  if (parts.isNotEmpty) {
    final weighed = parts.where(
      (p) => p.weight != null && p.state != LineState.missing,
    );
    if (weighed.isEmpty) return null;
    return weighed.fold<double>(0, (s, p) => s + p.weight!);
  }
  final kg = (product?.unit ?? ProductUnit.kg) == ProductUnit.kg;
  return kg ? line.weight : line.pieces?.toDouble();
}

int _money(double qty, int price) => (qty * price).round();

/// Сумма строки по факту, копейки; null — ещё не взвешено (нечего
/// считать). Не выдана — 0. [products] — по id, для цен частей.
int? lineAmount(
  SaleOrderLine line,
  Map<String, Product> products, {
  List<SaleOrderLine> parts = const [],
}) {
  if (line.state == LineState.missing) return 0;
  switch (line.pricing) {
    case LinePricing.fixed:
      return line.fixedAmount;
    case LinePricing.parts:
      final amounts = [
        for (final p in parts)
          if (p.state != LineState.missing) lineAmount(p, products),
      ];
      if (amounts.isEmpty || amounts.every((a) => a == null)) return null;
      return amounts.fold<int>(0, (s, a) => s + (a ?? 0));
    case LinePricing.list:
    case LinePricing.manual:
      final qty = factQty(line, products[line.productId], parts: parts);
      final price = line.price;
      if (qty == null || price == null) return null;
      return _money(qty, price);
  }
}

/// Предварительная сумма строки по заказанному, копейки; null — не
/// посчитать (заказано текстом или в других единицах).
int? lineEstimate(
  SaleOrderLine line,
  Map<String, Product> products, {
  List<SaleOrderLine> parts = const [],
}) {
  if (line.state == LineState.missing) return 0;
  if (line.pricing == LinePricing.fixed) return line.fixedAmount;
  final qty = line.orderedQty;
  if (line.orderedUnit == OrderedUnit.rub) {
    return qty == null ? null : (qty * 100).round();
  }
  if (line.pricing == LinePricing.parts) {
    final amounts = [for (final p in parts) lineEstimate(p, products)];
    if (amounts.isEmpty || amounts.any((a) => a == null)) {
      // Части без заказанного — по прайсу набора, если он есть.
      final price = line.price;
      return qty == null || price == null || line.orderedUnit != OrderedUnit.kg
          ? null
          : _money(qty, price);
    }
    return amounts.fold<int>(0, (s, a) => s + a!);
  }
  final price = line.price;
  if (qty == null || price == null) return null;
  final kg =
      (products[line.productId]?.unit ?? ProductUnit.kg) == ProductUnit.kg;
  final unitFits = kg
      ? line.orderedUnit == OrderedUnit.kg
      : line.orderedUnit == OrderedUnit.pcs;
  return unitFits ? _money(qty, price) : null;
}

/// Итоги заказа.
class OrderTotals {
  /// Сумма по факту по взвешенным строкам, копейки.
  final int fact;

  /// Предварительная сумма (по заказанному; взвешенные — по факту).
  final int estimate;

  /// Все строки взвешены или не выданы — [fact] окончательна.
  final bool complete;

  /// Строки, которые не посчитать заранее (заказано текстом).
  final int unknown;

  /// Вес по факту, кг (товары на вес).
  final double weight;

  const OrderTotals({
    required this.fact,
    required this.estimate,
    required this.complete,
    required this.unknown,
    required this.weight,
  });

  /// Сумма к оплате: окончательная или предварительная.
  int get due => complete ? fact : estimate;
}

/// Строки заказа [orderId]: верхние (набор и обычные) по порядку и части
/// наборов по строке набора.
({List<SaleOrderLine> top, Map<String, List<SaleOrderLine>> parts}) orderLines(
  Iterable<SaleOrderLine> lines,
  String orderId,
) {
  final top = <SaleOrderLine>[];
  final parts = <String, List<SaleOrderLine>>{};
  for (final l in lines) {
    if (l.orderId != orderId) continue;
    if (l.parentId == null) {
      top.add(l);
    } else {
      (parts[l.parentId!] ??= []).add(l);
    }
  }
  top.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  for (final list in parts.values) {
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }
  return (top: top, parts: parts);
}

OrderTotals orderTotals(
  Iterable<SaleOrderLine> lines,
  String orderId,
  Map<String, Product> products,
) {
  final (:top, :parts) = orderLines(lines, orderId);
  var fact = 0, estimate = 0, unknown = 0;
  var complete = true;
  var weight = 0.0;
  for (final l in top) {
    final ps = parts[l.id] ?? const <SaleOrderLine>[];
    final amount = lineAmount(l, products, parts: ps);
    if (amount != null) {
      fact += amount;
      estimate += amount;
      final kg =
          (products[l.productId]?.unit ?? ProductUnit.kg) == ProductUnit.kg;
      final qty = factQty(l, products[l.productId], parts: ps);
      if ((kg || ps.isNotEmpty) &&
          qty != null &&
          l.state != LineState.missing) {
        weight += qty;
      }
      continue;
    }
    complete = false;
    final e = lineEstimate(l, products, parts: ps);
    if (e == null) {
      unknown++;
    } else {
      estimate += e;
    }
  }
  return OrderTotals(
    fact: fact,
    estimate: estimate,
    complete: complete && top.isNotEmpty,
    unknown: unknown,
    weight: weight,
  );
}

// ------------------------------------------------------ отклонение веса

/// Допуск отклонения веса от заказанного по умолчанию (решение владельца
/// 2026-11-24): 15 %.
const defaultWeightTolerance = 0.15;

/// Отклонение факта от заказанного (0.3 — на 30 % больше); null —
/// сравнивать нечего (заказано не в кг или не взвешено).
double? weightDeviation(
  SaleOrderLine line, {
  List<SaleOrderLine> parts = const [],
}) {
  if (line.orderedUnit != OrderedUnit.kg) return null;
  final ordered = line.orderedQty;
  final fact = parts.isEmpty ? line.weight : factQty(line, null, parts: parts);
  if (ordered == null || ordered <= 0 || fact == null) return null;
  return (fact - ordered) / ordered;
}

/// Отклонение больше допуска — подсветить.
bool weightOff(
  SaleOrderLine line, {
  List<SaleOrderLine> parts = const [],
  double tolerance = defaultWeightTolerance,
}) {
  final d = weightDeviation(line, parts: parts);
  return d != null && d.abs() > tolerance;
}

// ------------------------------------------------------------- проверки

/// Почему заказ не записать; null — можно.
String? orderProblem(SaleOrder o) {
  if (o.customerId.isEmpty) return 'Выберите покупателя';
  if (o.batchId.isEmpty) return 'Выберите день выдачи';
  if (o.number < 1) return 'Номер заказа — с 1';
  return null;
}

/// Почему строку не записать; null — можно.
String? orderLineProblem(SaleOrderLine l) {
  if (l.productId.isEmpty) return 'Выберите товар';
  if ((l.orderedQty ?? 0) < 0) return 'Заказано — не меньше нуля';
  if ((l.weight ?? 0) < 0) return 'Вес — не меньше нуля';
  if ((l.pieces ?? 0) < 0) return 'Штуки — не меньше нуля';
  if (l.pricing == LinePricing.fixed && l.fixedAmount == null) {
    return 'Укажите сумму';
  }
  if (l.pricing == LinePricing.manual && l.price == null) {
    return 'Укажите цену';
  }
  return null;
}

/// Проверка строк при приёме (сервер): то же, что окна программы.
String? orderRowProblem(String table, Map<String, Object?> data) {
  if (table == 'sale_order_lines') {
    if (data['pricing'] == 'fixed' && data['fixed_amount'] == null) {
      return 'Своя сумма строки не указана';
    }
    if (data['pricing'] == 'manual' && data['price'] == null) {
      return 'Своя цена строки не указана';
    }
  }
  return null;
}
