import 'package:drift/drift.dart';
import 'package:kfh_domain/kfh_domain.dart';

import '../database.dart';
import '../tables/finance_tables.dart';
import 'sync_stamping.dart';

part 'finance_dao.g.dart';

/// Строит строку для записи: [now] и [editor] — отметка изменения,
/// [isNew] — запись добавляется (а не меняется).
typedef StampedRow<D> =
    Insertable<D> Function(DateTime now, String editor, bool isNew);

/// Финансы: справочники, операции, соответствия выплат ЗП.
@DriftAccessor(
  tables: [
    FinDirections,
    FinAllocationKeys,
    FinAllocationPeriods,
    FinAccounts,
    FinAssets,
    FinCategoryGroups,
    FinCategories,
    Counterparties,
    FinDebts,
    FinOperations,
    FinPayrollMapping,
  ],
)
class FinanceDao extends DatabaseAccessor<LocalDatabase>
    with _$FinanceDaoMixin, SyncStamping {
  FinanceDao(super.db);

  /// Добавляет запись [uuid] или меняет существующую. Удалённую запись
  /// так не вернуть — [StateError]. Повтор уникального значения (название
  /// и т. п.) — [DuplicateEntryException].
  Future<void> saveRow<T extends Table, D>(
    TableInfo<T, D> table,
    String uuid,
    StampedRow<D> build,
  ) async {
    final editor = await db.deviceId();
    await _unique(
      () => transaction(() async {
        final existing = await customSelect(
          'SELECT deleted FROM ${table.actualTableName} WHERE uuid = ?',
          variables: [Variable<String>(uuid)],
          readsFrom: {table},
        ).getSingleOrNull();
        final now = db.nowUtc();
        if (existing == null) {
          await into(table).insert(build(now, editor, true));
          return;
        }
        if (existing.read<bool>('deleted')) {
          throw StateError('Запись удалена: $uuid');
        }
        final row = build(now, editor, false);
        await (update(table)..whereSamePrimaryKey(row)).write(row);
      }),
    );
  }

  /// Нарушение уникального индекса → [DuplicateEntryException]. Текст
  /// ошибки SQLite одинаков на всех платформах (в браузере — внутри
  /// ошибки drift).
  Future<R> _unique<R>(Future<R> Function() action) async {
    try {
      return await action();
    } catch (e) {
      if ('$e'.contains('UNIQUE constraint failed')) {
        throw const DuplicateEntryException('Такая запись уже есть');
      }
      rethrow;
    }
  }

  /// Запись [uuid] есть в таблице (даже удалённая).
  Future<bool> exists(TableInfo table, String uuid) async =>
      await customSelect(
        'SELECT 1 FROM ${table.actualTableName} WHERE uuid = ?',
        variables: [Variable<String>(uuid)],
        readsFrom: {table},
      ).getSingleOrNull() !=
      null;

  Future<int> softDelete(TableInfo table, String uuid) =>
      softDeleteRow(table, uuid);

  Future<List<FinDirectionRow>> allDirections() =>
      (select(finDirections)
            ..where((t) => t.deleted.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

  Future<List<FinAllocationKeyRow>> allKeys() =>
      (select(finAllocationKeys)..where((t) => t.deleted.equals(false))).get();

  Future<List<FinAllocationPeriodRow>> allPeriods() =>
      (select(finAllocationPeriods)
            ..where((t) => t.deleted.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.validFrom)]))
          .get();

  Future<List<FinAccountRow>> allAccounts() =>
      (select(finAccounts)
            ..where((t) => t.deleted.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

  Future<List<FinAssetRow>> allAssets() =>
      (select(finAssets)..where((t) => t.deleted.equals(false))).get();

  Future<List<FinCategoryGroupRow>> allCategoryGroups() =>
      (select(finCategoryGroups)
            ..where((t) => t.deleted.equals(false))
            ..orderBy([
              (t) => OrderingTerm(expression: t.sortOrder),
              (t) => OrderingTerm(expression: t.name),
            ]))
          .get();

  Future<FinCategoryGroupRow?> categoryGroupByUuid(String uuid) => (select(
    finCategoryGroups,
  )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();

  /// Живые статьи группы: по ссылке или (записи 1.18) по виду и названию.
  Future<List<FinCategoryRow>> categoriesOfGroup(
    String groupUuid,
    String type,
    String name,
  ) =>
      (select(finCategories)..where(
            (t) =>
                t.deleted.equals(false) &
                (t.groupUuid.equals(groupUuid) |
                    (t.groupUuid.isNull() &
                        t.type.equals(type) &
                        t.groupName.equals(name))),
          ))
          .get();

  Future<List<FinCategoryRow>> allCategories() =>
      (select(finCategories)
            ..where((t) => t.deleted.equals(false))
            ..orderBy([
              (t) => OrderingTerm(expression: t.groupName),
              (t) => OrderingTerm(expression: t.sortOrder),
              (t) => OrderingTerm(expression: t.name),
            ]))
          .get();

  Future<List<CounterpartyRow>> allCounterparties() =>
      (select(counterparties)
            ..where((t) => t.deleted.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.name)]))
          .get();

  Future<List<FinDebtRow>> allDebts() =>
      (select(finDebts)..where((t) => t.deleted.equals(false))).get();

  Future<List<FinPayrollMappingRow>> allPayrollMapping() =>
      (select(finPayrollMapping)..where((t) => t.deleted.equals(false))).get();

  Future<FinOperationRow?> operationByUuid(String uuid) =>
      (select(finOperations)
            ..where((t) => t.uuid.equals(uuid) & t.deleted.equals(false)))
          .getSingleOrNull();

  /// Операции по дате (новые сверху). [from]/[to] — дни включительно;
  /// [accountUuid] — кошелёк как источник или получатель перевода;
  /// [season] — сезон урожая (не указан — год даты операции).
  Future<List<FinOperationRow>> operationsList({
    DateTime? from,
    DateTime? to,
    String? accountUuid,
    int? season,
  }) {
    final query = select(finOperations)..where((t) => t.deleted.equals(false));
    if (from != null) {
      query.where((t) => t.date.isBiggerOrEqualValue(formatDateIso(from)));
    }
    if (to != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(formatDateIso(to)));
    }
    if (accountUuid != null) {
      query.where(
        (t) =>
            t.accountUuid.equals(accountUuid) |
            t.toAccountUuid.equals(accountUuid),
      );
    }
    if (season != null) {
      query.where(
        (t) =>
            t.season.equals(season) |
            (t.season.isNull() &
                t.date.substr(1, 4).equals(season.toString().padLeft(4, '0'))),
      );
    }
    query.orderBy([
      (t) => OrderingTerm.desc(t.date),
      (t) => OrderingTerm.desc(t.createdAt),
    ]);
    return query.get();
  }
}
