// Заказы на drift (этап 11.4): строки таблиц ↔ модели kfh_domain.

import 'package:drift/drift.dart';
import 'package:kfh_domain/kfh_domain.dart';

import '../database.dart';

class DriftOrderRepository implements OrderRepository {
  final LocalDatabase _db;
  DriftOrderRepository(this._db);

  static String? _text(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  @override
  Future<List<SaleBatch>> batches() async => [
    for (final r in await _db.salesDao.allBatches())
      SaleBatch(
        id: r.uuid,
        day: parseDateIso(r.day),
        dayTo: parseDateIsoOrNull(r.dayTo),
        title: r.title,
        notes: r.notes,
      ),
  ];

  @override
  Future<void> saveBatch(SaleBatch b) => _db.salesDao.saveRow(
    _db.saleBatches,
    b.id,
    (now, editor, isNew) => SaleBatchesCompanion(
      uuid: Value(b.id),
      day: Value(formatDateIso(b.day)),
      dayTo: Value(formatDateIsoOrNull(b.dayTo)),
      title: Value(_text(b.title)),
      notes: Value(_text(b.notes)),
      deleted: const Value(false),
      updatedAt: Value(now),
      editedBy: Value(editor),
    ),
  );

  @override
  Future<List<SaleOrder>> orders() async => [
    for (final r in await _db.salesDao.allOrders())
      SaleOrder(
        id: r.uuid,
        batchId: r.batchUuid,
        customerId: r.customerUuid,
        number: r.number,
        kind: OrderKind.fromCode(r.kind),
        delivery: Delivery.fromCode(r.delivery),
        address: r.address,
        comment: r.comment,
        status: OrderStatus.fromCode(r.status),
        createdBy: r.createdBy,
      ),
  ];

  static SaleOrderLine _line(SaleOrderLineRow r) => SaleOrderLine(
    id: r.uuid,
    orderId: r.orderUuid,
    parentId: r.parentLineUuid,
    productId: r.productUuid,
    sortOrder: r.sortOrder,
    orderedQty: r.orderedQty,
    orderedUnit: OrderedUnit.fromCode(r.orderedUnit),
    orderedText: r.orderedText,
    weight: r.weight,
    pieces: r.pieces,
    pricing: LinePricing.fromCode(r.pricing),
    price: r.price,
    fixedAmount: r.fixedAmount,
    state: LineState.fromCode(r.state),
    note: r.note,
    added: r.added,
  );

  @override
  Future<List<SaleOrderLine>> lines() async => [
    for (final r in await _db.salesDao.allOrderLines()) _line(r),
  ];

  Future<void> _saveLine(SaleOrderLine l) => _db.salesDao.saveRow(
    _db.saleOrderLines,
    l.id,
    (now, editor, isNew) => SaleOrderLinesCompanion(
      uuid: Value(l.id),
      orderUuid: Value(l.orderId),
      parentLineUuid: Value(l.parentId),
      productUuid: Value(l.productId),
      sortOrder: Value(l.sortOrder),
      orderedQty: Value(l.orderedQty),
      orderedUnit: Value(l.orderedUnit?.code),
      orderedText: Value(_text(l.orderedText)),
      weight: Value(l.weight),
      pieces: Value(l.pieces),
      pricing: Value(l.pricing.code),
      price: Value(l.price),
      fixedAmount: Value(l.fixedAmount),
      state: Value(l.state.code),
      note: Value(_text(l.note)),
      added: Value(l.added),
      deleted: const Value(false),
      updatedAt: Value(now),
      editedBy: Value(editor),
    ),
  );

  @override
  Future<void> saveOrder(SaleOrder o, List<SaleOrderLine> lines) =>
      _db.transaction(() async {
        await _db.salesDao.saveRow(
          _db.saleOrders,
          o.id,
          (now, editor, isNew) => SaleOrdersCompanion(
            uuid: Value(o.id),
            batchUuid: Value(o.batchId),
            customerUuid: Value(o.customerId),
            number: Value(o.number),
            kind: Value(o.kind.code),
            delivery: Value(o.delivery.code),
            address: Value(_text(o.address)),
            comment: Value(_text(o.comment)),
            status: Value(o.status.code),
            createdBy: Value(o.createdBy),
            deleted: const Value(false),
            updatedAt: Value(now),
            editedBy: Value(editor),
          ),
        );
        final keep = {for (final l in lines) l.id};
        for (final old in await _db.salesDao.linesOfOrder(o.id)) {
          if (!keep.contains(old.uuid)) {
            await _db.salesDao.softDelete(_db.saleOrderLines, old.uuid);
          }
        }
        // Сначала строки наборов, потом их части.
        for (final l in lines.where((l) => l.parentId == null)) {
          await _saveLine(l);
        }
        for (final l in lines.where((l) => l.parentId != null)) {
          await _saveLine(l);
        }
      });

  @override
  Future<void> deleteOrder(String id) => _db.transaction(() async {
    for (final l in await _db.salesDao.linesOfOrder(id)) {
      await _db.salesDao.softDelete(_db.saleOrderLines, l.uuid);
    }
    await _db.salesDao.softDelete(_db.saleOrders, id);
  });
}
