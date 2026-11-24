import 'package:drift/drift.dart';
import 'package:kfh_domain/kfh_domain.dart';

import '../database.dart';
import '../tables/finance_tables.dart';
import 'sync_stamping.dart';

part 'finance_dao.g.dart';

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
    FinPlans,
    FinBudget,
  ],
)
class FinanceDao extends DatabaseAccessor<LocalDatabase>
    with _$FinanceDaoMixin, SyncStamping {
  FinanceDao(super.db);

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

  Future<List<FinPlanRow>> allPlans() =>
      (select(finPlans)
            ..where((t) => t.deleted.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.startDate)]))
          .get();

  Future<List<FinBudgetRow>> budgetOf(int year) => (select(
    finBudget,
  )..where((t) => t.deleted.equals(false) & t.year.equals(year))).get();

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
