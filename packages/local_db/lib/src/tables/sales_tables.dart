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
