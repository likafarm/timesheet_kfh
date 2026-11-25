// Таблицы продаж (этап 11, схема drift 6): прайс-лист — группы, товары и
// цены с даты. Цены — копейки целым числом, дни — строки `гггг-мм-дд`.
// Как у остальных бизнес-таблиц: служебные поля синхронизации, мягкое
// удаление, уникальные индексы только среди неудалённых строк, отложенные
// внешние ключи.

import 'package:drift/drift.dart';

import 'finance_tables.dart';
import 'tables.dart';

@DataClassName('ProductGroupRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_product_groups_name '
  'ON product_groups (name) WHERE deleted = 0',
)
class ProductGroups extends Table with SyncColumns {
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('ProductRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_products_name '
  'ON products (name) WHERE deleted = 0',
)
class Products extends Table with SyncColumns {
  TextColumn get groupUuid =>
      text().references(ProductGroups, #uuid, initiallyDeferred: true)();
  TextColumn get name => text()();

  /// `ProductUnit.code`: kg, pcs, pack, can.
  TextColumn get unit => text().withDefault(const Constant('kg'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
}

/// Цена товара с дня `valid_from` (копейки за единицу товара).
@DataClassName('ProductPriceRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_product_prices_key '
  'ON product_prices (product_uuid, valid_from) WHERE deleted = 0',
)
class ProductPrices extends Table with SyncColumns {
  TextColumn get productUuid =>
      text().references(Products, #uuid, initiallyDeferred: true)();
  TextColumn get validFrom => text()();
  IntColumn get price => integer()();
}

/// Покупатели (этап 11.3, схема 7): отдельно от контрагентов финансов.
/// `counterparty_uuid` — контрагент, на которого пишутся оплаты (11.6).
@DataClassName('CustomerRow')
@TableIndex(name: 'idx_customers_name', columns: {#name})
class Customers extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();

  /// `CustomerChannel.code`
  TextColumn get channel => text().nullable()();
  TextColumn get contact => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get counterpartyUuid => text().nullable().references(
    Counterparties,
    #uuid,
    initiallyDeferred: true,
  )();
}

/// Выдача (этап 11.4, схема 7): день забоя / выдачи; `day_to` — диапазон
/// для перенесённой истории.
@DataClassName('SaleBatchRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_sale_batches_day '
  'ON sale_batches (day) WHERE deleted = 0',
)
class SaleBatches extends Table with SyncColumns {
  TextColumn get day => text()();
  TextColumn get dayTo => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get notes => text().nullable()();
}

/// Заказ (этап 11.4, схема 7). Номер в выдаче не уникален: два устройства
/// без связи могли дать один номер — правится вручную, данные не теряются.
@DataClassName('SaleOrderRow')
@TableIndex(name: 'idx_sale_orders_batch', columns: {#batchUuid})
@TableIndex(name: 'idx_sale_orders_customer', columns: {#customerUuid})
class SaleOrders extends Table with SyncColumns {
  TextColumn get batchUuid =>
      text().references(SaleBatches, #uuid, initiallyDeferred: true)();
  TextColumn get customerUuid =>
      text().references(Customers, #uuid, initiallyDeferred: true)();
  IntColumn get number => integer()();

  /// `OrderKind.code`
  TextColumn get kind => text().withDefault(const Constant('sale'))();

  /// `Delivery.code`
  TextColumn get delivery => text().withDefault(const Constant('pickup'))();
  TextColumn get address => text().nullable()();
  TextColumn get comment => text().nullable()();

  /// `OrderStatus.code`
  TextColumn get status => text().withDefault(const Constant('new'))();
  TextColumn get createdBy => text().nullable()();
}

/// Строка заказа (этап 11.4, схема 7): «заказано» и «фактически» отдельно;
/// часть набора — `parent_line_uuid`.
@DataClassName('SaleOrderLineRow')
@TableIndex(name: 'idx_sale_order_lines_order', columns: {#orderUuid})
class SaleOrderLines extends Table with SyncColumns {
  TextColumn get orderUuid =>
      text().references(SaleOrders, #uuid, initiallyDeferred: true)();
  TextColumn get parentLineUuid => text().nullable().references(
    SaleOrderLines,
    #uuid,
    initiallyDeferred: true,
  )();
  TextColumn get productUuid =>
      text().references(Products, #uuid, initiallyDeferred: true)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  RealColumn get orderedQty => real().nullable()();

  /// `OrderedUnit.code`
  TextColumn get orderedUnit => text().nullable()();
  TextColumn get orderedText => text().nullable()();
  RealColumn get weight => real().nullable()();
  IntColumn get pieces => integer().nullable()();

  /// `LinePricing.code`
  TextColumn get pricing => text().withDefault(const Constant('list'))();
  IntColumn get price => integer().nullable()();
  IntColumn get fixedAmount => integer().nullable()();

  /// `LineState.code`
  TextColumn get state => text().withDefault(const Constant('open'))();
  TextColumn get note => text().nullable()();
  BoolColumn get added => boolean().withDefault(const Constant(false))();
}
