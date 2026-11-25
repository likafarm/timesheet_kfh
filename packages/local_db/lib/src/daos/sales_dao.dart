import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/sales_tables.dart';
import 'sync_stamping.dart';

part 'sales_dao.g.dart';

/// Продажи (этап 11): прайс-лист — группы, товары, цены; покупатели.
@DriftAccessor(
  tables: [
    ProductGroups,
    Products,
    ProductPrices,
    Customers,
    SaleBatches,
    SaleOrders,
    SaleOrderLines,
  ],
)
class SalesDao extends DatabaseAccessor<LocalDatabase>
    with _$SalesDaoMixin, SyncStamping {
  SalesDao(super.db);

  Future<int> softDelete(TableInfo table, String uuid) =>
      softDeleteRow(table, uuid);

  Future<List<ProductGroupRow>> allGroups() =>
      (select(productGroups)
            ..where((t) => t.deleted.equals(false))
            ..orderBy([
              (t) => OrderingTerm(expression: t.sortOrder),
              (t) => OrderingTerm(expression: t.name),
            ]))
          .get();

  Future<List<ProductRow>> allProducts() =>
      (select(products)
            ..where((t) => t.deleted.equals(false))
            ..orderBy([
              (t) => OrderingTerm(expression: t.sortOrder),
              (t) => OrderingTerm(expression: t.name),
            ]))
          .get();

  Future<List<ProductPriceRow>> allPrices() =>
      (select(productPrices)
            ..where((t) => t.deleted.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.validFrom)]))
          .get();

  Future<List<CustomerRow>> allCustomers() =>
      (select(customers)
            ..where((t) => t.deleted.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.name)]))
          .get();

  Future<List<SaleBatchRow>> allBatches() =>
      (select(saleBatches)
            ..where((t) => t.deleted.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.day)]))
          .get();

  Future<List<SaleOrderRow>> allOrders() =>
      (select(saleOrders)..where((t) => t.deleted.equals(false))).get();

  Future<List<SaleOrderLineRow>> allOrderLines() =>
      (select(saleOrderLines)..where((t) => t.deleted.equals(false))).get();

  Future<List<SaleOrderLineRow>> linesOfOrder(String orderUuid) =>
      (select(saleOrderLines)..where(
            (t) => t.deleted.equals(false) & t.orderUuid.equals(orderUuid),
          ))
          .get();

  /// Живые товары группы [groupUuid].
  Future<int> productCountInGroup(String groupUuid) async =>
      (await (select(products)..where(
                (t) => t.deleted.equals(false) & t.groupUuid.equals(groupUuid),
              ))
              .get())
          .length;

  /// Живые цены товара [productUuid].
  Future<int> priceCountOfProduct(String productUuid) async =>
      (await (select(productPrices)..where(
                (t) =>
                    t.deleted.equals(false) & t.productUuid.equals(productUuid),
              ))
              .get())
          .length;
}
