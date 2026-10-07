// Таблицы финансов (этап 8, схема drift 2).
//
// Суммы — копейки целым числом, дни — строки `гггг-мм-дд`, перечисления —
// коды моделей kfh_domain (`AccountKind.code` и т. д.). Как у остальных
// бизнес-таблиц: служебные поля синхронизации, мягкое удаление, уникальные
// индексы только среди неудалённых строк, отложенные внешние ключи.

import 'package:drift/drift.dart';

import 'tables.dart';

@DataClassName('FinDirectionRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_fin_directions_name '
  'ON fin_directions (name) WHERE deleted = 0',
)
class FinDirections extends Table with SyncColumns {
  TextColumn get name => text()();
  BoolColumn get overhead => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('FinAllocationKeyRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_fin_allocation_keys_name '
  'ON fin_allocation_keys (name) WHERE deleted = 0',
)
class FinAllocationKeys extends Table with SyncColumns {
  TextColumn get name => text()();
}

/// Версия долей ключа: одна строка на дату начала, доли — JSON
/// `{"uuid направления": процент}` (синхронизация сравнивает строки
/// целиком — доли одной версии не склеятся из правок разных устройств).
@DataClassName('FinAllocationPeriodRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_fin_allocation_periods_unique '
  'ON fin_allocation_periods (key_uuid, valid_from) WHERE deleted = 0',
)
class FinAllocationPeriods extends Table with SyncColumns {
  TextColumn get keyUuid =>
      text().references(FinAllocationKeys, #uuid, initiallyDeferred: true)();
  TextColumn get validFrom => text()();
  TextColumn get shares => text()();
}

@DataClassName('FinAccountRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_fin_accounts_name '
  'ON fin_accounts (name) WHERE deleted = 0',
)
class FinAccounts extends Table with SyncColumns {
  TextColumn get name => text()();

  /// `AccountKind.code`
  TextColumn get kind => text()();
  IntColumn get openingBalance => integer().withDefault(const Constant(0))();
  TextColumn get openingDate => text().nullable()();
  TextColumn get employeeUuid =>
      text().nullable().references(Employees, #uuid, initiallyDeferred: true)();
  BoolColumn get closed => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('FinAssetRow')
class FinAssets extends Table with SyncColumns {
  TextColumn get name => text()();

  /// `AssetKind.code`
  TextColumn get kind => text()();
  IntColumn get year => integer().nullable()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  IntColumn get referenceValue => integer().nullable()();
  TextColumn get valuedOn => text().nullable()();
  TextColumn get directionUuid => text().nullable().references(
    FinDirections,
    #uuid,
    initiallyDeferred: true,
  )();
  TextColumn get allocationKeyUuid => text().nullable().references(
    FinAllocationKeys,
    #uuid,
    initiallyDeferred: true,
  )();
  TextColumn get cadastralNumber => text().nullable()();
  RealColumn get areaHa => real().nullable()();
  IntColumn get cadastralValue => integer().nullable()();
  TextColumn get disposedOn => text().nullable()();
  TextColumn get disposalReason => text().nullable()();
  TextColumn get notes => text().nullable()();
}

@DataClassName('FinCategoryRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_fin_categories_name '
  'ON fin_categories (type, name) WHERE deleted = 0',
)
class FinCategories extends Table with SyncColumns {
  /// `CategoryType.code`
  TextColumn get type => text()();
  TextColumn get groupName => text()();
  TextColumn get name => text()();
  TextColumn get directionUuid => text().nullable().references(
    FinDirections,
    #uuid,
    initiallyDeferred: true,
  )();
  TextColumn get allocationKeyUuid => text().nullable().references(
    FinAllocationKeys,
    #uuid,
    initiallyDeferred: true,
  )();

  /// `CategoryKind.code`
  TextColumn get kind => text().withDefault(const Constant('current'))();
  BoolColumn get inTaxBook => boolean().withDefault(const Constant(true))();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('CounterpartyRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_counterparties_name '
  'ON counterparties (name) WHERE deleted = 0',
)
class Counterparties extends Table with SyncColumns {
  TextColumn get name => text()();

  /// `CounterpartyKind.code`
  TextColumn get kind => text().withDefault(const Constant('other'))();
  TextColumn get inn => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get employeeUuid =>
      text().nullable().references(Employees, #uuid, initiallyDeferred: true)();
  TextColumn get notes => text().nullable()();
}

@DataClassName('FinDebtRow')
class FinDebts extends Table with SyncColumns {
  TextColumn get counterpartyUuid =>
      text().references(Counterparties, #uuid, initiallyDeferred: true)();

  /// `DebtKind.code`
  TextColumn get kind => text()();
  IntColumn get openingBalance => integer().withDefault(const Constant(0))();
  TextColumn get openingDate => text().nullable()();
  BoolColumn get closed => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
}

@DataClassName('FinOperationRow')
@TableIndex(name: 'idx_fin_operations_date', columns: {#date})
@TableIndex(name: 'idx_fin_operations_account', columns: {#accountUuid, #date})
@TableIndex(name: 'idx_fin_operations_category', columns: {#categoryUuid})
class FinOperations extends Table with SyncColumns {
  TextColumn get date => text()();

  /// `OperationType.code`
  TextColumn get type => text()();
  IntColumn get amount => integer()();
  TextColumn get accountUuid =>
      text().references(FinAccounts, #uuid, initiallyDeferred: true)();
  TextColumn get toAccountUuid => text().nullable().references(
    FinAccounts,
    #uuid,
    initiallyDeferred: true,
  )();
  TextColumn get categoryUuid => text().nullable().references(
    FinCategories,
    #uuid,
    initiallyDeferred: true,
  )();
  TextColumn get directionUuid => text().nullable().references(
    FinDirections,
    #uuid,
    initiallyDeferred: true,
  )();
  TextColumn get allocationKeyUuid => text().nullable().references(
    FinAllocationKeys,
    #uuid,
    initiallyDeferred: true,
  )();
  TextColumn get assetUuid =>
      text().nullable().references(FinAssets, #uuid, initiallyDeferred: true)();
  IntColumn get season => integer().nullable()();
  TextColumn get counterpartyUuid => text().nullable().references(
    Counterparties,
    #uuid,
    initiallyDeferred: true,
  )();
  TextColumn get employeeUuid =>
      text().nullable().references(Employees, #uuid, initiallyDeferred: true)();
  TextColumn get debtUuid =>
      text().nullable().references(FinDebts, #uuid, initiallyDeferred: true)();

  /// `DebtMove.code`
  TextColumn get debtMove => text().nullable()();
  TextColumn get description => text().nullable()();
  RealColumn get quantity => real().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get tag => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// `OperationSource.code`
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get sourceRef => text().nullable()();

  /// Кто внёс (логин пользователя; устройство — в `edited_by`).
  TextColumn get createdBy => text().nullable()();
  TextColumn get createdAt => text()();
}

/// Соответствия «выплата ЗП → расход»: вид (`method` — способ выплаты →
/// кошелёк, `position` — должность → статья, `default_account`,
/// `default_category`), значение (для умолчаний — пусто) и uuid кошелька
/// или статьи.
@DataClassName('FinPayrollMappingRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_fin_payroll_mapping_unique '
  'ON fin_payroll_mapping (kind, value) WHERE deleted = 0',
)
class FinPayrollMapping extends Table with SyncColumns {
  @override
  String get tableName => 'fin_payroll_mapping';

  TextColumn get kind => text()();
  TextColumn get value => text().withDefault(const Constant(''))();
  TextColumn get targetUuid => text()();
}
