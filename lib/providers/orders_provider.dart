// lib/providers/orders_provider.dart
//
// Заказы (этап 11.4) поверх базы [AppProvider]: выдачи, заказы, строки,
// а для них — покупатели и прайс (цена строки — по прайсу на день
// выдачи). Ведут специалист по продажам, бухгалтер и админ. Нарушение —
// сообщение внизу окна и false.

import 'package:flutter/foundation.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart' show newUuid;

import 'app_provider.dart';

class OrdersProvider extends ChangeNotifier {
  OrdersProvider(this._app) : _seenVersion = _app.dataVersion {
    _app.addListener(_onApp);
  }

  final AppProvider _app;
  int _seenVersion;

  OrderRepository get _repo => _app.repos.orders;

  bool _loaded = false;
  bool get loaded => _loaded;

  List<SaleBatch> _batches = const [];
  List<SaleOrder> _orders = const [];
  List<SaleOrderLine> _lines = const [];
  Map<String, Customer> _customers = const {};
  List<ProductGroup> _groups = const [];
  Map<String, Product> _products = const {};
  List<ProductPrice> _prices = const [];

  /// Выдачи, новые сначала.
  List<SaleBatch> get batches => _batches;
  List<SaleOrder> get orders => _orders;
  Map<String, Customer> get customers => _customers;
  Map<String, Product> get products => _products;
  List<ProductGroup> get groups => _groups;

  bool get canEdit => !_app.operatorMode;

  String newId() => newUuid();

  void _onApp() {
    if (_app.dataVersion != _seenVersion) {
      _seenVersion = _app.dataVersion;
      if (_loaded) load();
    }
  }

  @override
  void dispose() {
    _app.removeListener(_onApp);
    super.dispose();
  }

  Future<void> load() async {
    final repos = _app.repos;
    _batches = (await _repo.batches())..sort((a, b) => b.day.compareTo(a.day));
    _orders = await _repo.orders();
    _lines = await _repo.lines();
    _customers = {for (final c in await repos.customers.customers()) c.id: c};
    _groups = sortedGroups(await repos.priceList.groups());
    _products = {for (final p in await repos.priceList.products()) p.id: p};
    _prices = await repos.priceList.prices();
    _loaded = true;
    notifyListeners();
  }

  SaleBatch? batch(String id) {
    for (final b in _batches) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Ближайшая выдача: первая с сегодняшнего дня, иначе последняя.
  SaleBatch? get nearestBatch {
    final today = calendarDay(DateTime.now());
    SaleBatch? next;
    for (final b in _batches) {
      if (!calendarDay(b.day).isBefore(today)) next = b; // новые сначала
    }
    return next ?? (_batches.isEmpty ? null : _batches.first);
  }

  /// Заказы выдачи [batchId] по номеру.
  List<SaleOrder> ordersOf(String batchId) => [
    for (final o in _orders)
      if (o.batchId == batchId) o,
  ]..sort((a, b) => a.number.compareTo(b.number));

  /// Заказы покупателя, новые сначала.
  List<SaleOrder> ordersOfCustomer(String customerId) {
    final list = [
      for (final o in _orders)
        if (o.customerId == customerId) o,
    ];
    list.sort((a, b) {
      final da = batch(a.batchId)?.day, db = batch(b.batchId)?.day;
      if (da == null || db == null) return 0;
      return db.compareTo(da);
    });
    return list;
  }

  List<SaleOrderLine> linesOf(String orderId) => [
    for (final l in _lines)
      if (l.orderId == orderId) l,
  ];

  OrderTotals totals(String orderId) =>
      orderTotals(linesOf(orderId), orderId, _products);

  String label(SaleOrder o) {
    final b = batch(o.batchId);
    return b == null ? '${o.number}' : orderLabel(b, o);
  }

  /// Цена товара по прайсу на день [day], копейки; null — цены нет.
  int? priceOn(String productId, DateTime day) =>
      priceAt(_prices, productId, day)?.price;

  /// Продающиеся товары прайса по группам — для выбора в строку.
  PriceListView catalog(DateTime day) => buildPriceList(
    groups: _groups,
    products: _products.values,
    prices: _prices,
    day: day,
  );

  /// Выдача на день [day]: есть — она, нет — новая (ещё не записана).
  SaleBatch batchFor(DateTime day) =>
      batchOn(_batches, day) ?? SaleBatch(id: newId(), day: calendarDay(day));

  int nextNumber(String batchId) => nextOrderNumber(_orders, batchId);

  /// Новый заказ покупателю [customerId] на выдачу [batch].
  SaleOrder draft(SaleBatch batch, String customerId) => SaleOrder(
    id: newId(),
    batchId: batch.id,
    customerId: customerId,
    number: nextNumber(batch.id),
    createdBy: _app.userUuid,
  );

  /// Строки заказа [source] для нового заказа [target] (повтор заказа):
  /// только заказанное, факта нет, цены — по прайсу на день [day].
  List<SaleOrderLine> repeatLines(String source, String target, DateTime day) {
    final ids = <String, String>{};
    final all = linesOf(source).where((l) => !l.added).toList();
    for (final l in all) {
      ids[l.id] = newId();
    }
    // Часть набора, добавленного при сборке, не повторяется.
    final old = [
      for (final l in all)
        if (l.parentId == null || ids.containsKey(l.parentId)) l,
    ];
    return [
      for (final l in old)
        SaleOrderLine(
          id: ids[l.id]!,
          orderId: target,
          parentId: l.parentId == null ? null : ids[l.parentId],
          productId: l.productId,
          sortOrder: l.sortOrder,
          orderedQty: l.orderedQty,
          orderedUnit: l.orderedUnit,
          orderedText: l.orderedText,
          pricing: l.pricing,
          price: l.pricing == LinePricing.manual
              ? l.price
              : priceOn(l.productId, day),
          fixedAmount: l.fixedAmount,
        ),
    ];
  }

  // ------------------------------------------------------------- правка

  String? get lastProblem => _lastProblem;
  String? _lastProblem;

  bool _fail(String message) {
    _lastProblem = message;
    _app.showNotice(message);
    return false;
  }

  /// Записать заказ со строками; выдачу [batch] — если её ещё нет.
  Future<bool> save(
    SaleOrder order,
    List<SaleOrderLine> lines, {
    required SaleBatch batch,
  }) async {
    _lastProblem = null;
    if (!canEdit) return _fail('Заказы ведут продавец и бухгалтер');
    final problem =
        orderProblem(order) ??
        (lines.isEmpty ? 'Добавьте хотя бы один товар' : null) ??
        lines.map(orderLineProblem).nonNulls.firstOrNull;
    if (problem != null) return _fail('Не сохранено: $problem');
    try {
      if (this.batch(batch.id) == null) await _repo.saveBatch(batch);
      await _repo.saveOrder(order.copyWith(batchId: batch.id), lines);
    } catch (e) {
      return _fail('Не сохранено: $e');
    }
    await load();
    return true;
  }

  Future<bool> delete(String orderId) async {
    _lastProblem = null;
    if (!canEdit) return _fail('Заказы ведут продавец и бухгалтер');
    try {
      await _repo.deleteOrder(orderId);
    } catch (e) {
      return _fail('Не удалено: $e');
    }
    await load();
    return true;
  }

  /// Состояние заказа — одной кнопкой из списка.
  Future<bool> setStatus(SaleOrder order, OrderStatus status) => save(
    order.copyWith(status: status),
    linesOf(order.id),
    batch: batch(order.batchId)!,
  );

  /// Покупатель для нового заказа — новый (из окна заказа).
  Future<bool> addCustomer(Customer c) async {
    final problem = customerProblem(c);
    if (problem != null) return _fail('Не сохранено: $problem');
    await _app.repos.customers.saveCustomer(c);
    await load();
    return true;
  }
}
