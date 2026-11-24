// Прайс-лист на drift (этап 11.1): строки таблиц ↔ модели kfh_domain.
// Запросы — в SalesDao, здесь только преобразование.

import 'package:drift/drift.dart';
import 'package:kfh_domain/kfh_domain.dart';

import '../database.dart';

class DriftPriceListRepository implements PriceListRepository {
  final LocalDatabase _db;
  DriftPriceListRepository(this._db);

  @override
  Future<List<ProductGroup>> groups() async => [
    for (final r in await _db.salesDao.allGroups())
      ProductGroup(id: r.uuid, name: r.name, sortOrder: r.sortOrder),
  ];

  @override
  Future<List<Product>> products() async => [
    for (final r in await _db.salesDao.allProducts())
      Product(
        id: r.uuid,
        groupId: r.groupUuid,
        name: r.name,
        unit: ProductUnit.fromCode(r.unit),
        sortOrder: r.sortOrder,
        hidden: r.hidden,
        notes: r.notes,
      ),
  ];

  @override
  Future<List<ProductPrice>> prices() async => [
    for (final r in await _db.salesDao.allPrices())
      ProductPrice(
        id: r.uuid,
        productId: r.productUuid,
        validFrom: parseDateIso(r.validFrom),
        price: r.price,
      ),
  ];

  @override
  Future<void> saveGroup(ProductGroup g) => _db.salesDao.saveRow(
    _db.productGroups,
    g.id,
    (now, editor, isNew) => ProductGroupsCompanion(
      uuid: Value(g.id),
      name: Value(g.name.trim()),
      sortOrder: Value(g.sortOrder),
      deleted: const Value(false),
      updatedAt: Value(now),
      editedBy: Value(editor),
    ),
  );

  @override
  Future<void> deleteGroup(String id) async {
    if (await _db.salesDao.productCountInGroup(id) > 0) {
      throw StateError('В группе есть товары — сначала перенесите их');
    }
    await _db.salesDao.softDelete(_db.productGroups, id);
  }

  @override
  Future<void> saveProduct(Product p) => _db.salesDao.saveRow(
    _db.products,
    p.id,
    (now, editor, isNew) => ProductsCompanion(
      uuid: Value(p.id),
      groupUuid: Value(p.groupId),
      name: Value(p.name.trim()),
      unit: Value(p.unit.code),
      sortOrder: Value(p.sortOrder),
      hidden: Value(p.hidden),
      notes: Value(p.notes),
      deleted: const Value(false),
      updatedAt: Value(now),
      editedBy: Value(editor),
    ),
  );

  @override
  Future<void> deleteProduct(String id) async {
    if (await _db.salesDao.priceCountOfProduct(id) > 0) {
      throw StateError(
        'У товара есть цены — его можно только скрыть («Не продаётся»)',
      );
    }
    await _db.salesDao.softDelete(_db.products, id);
  }

  @override
  Future<void> savePrices(Iterable<ProductPrice> prices) =>
      _db.transaction(() async {
        for (final p in prices) {
          await _db.salesDao.saveRow(
            _db.productPrices,
            p.id,
            (now, editor, isNew) => ProductPricesCompanion(
              uuid: Value(p.id),
              productUuid: Value(p.productId),
              validFrom: Value(formatDateIso(p.validFrom)),
              price: Value(p.price),
              deleted: const Value(false),
              updatedAt: Value(now),
              editedBy: Value(editor),
            ),
          );
        }
      });

  @override
  Future<void> deletePrice(String id) =>
      _db.salesDao.softDelete(_db.productPrices, id);
}
