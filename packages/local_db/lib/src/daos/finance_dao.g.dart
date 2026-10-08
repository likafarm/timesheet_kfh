// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finance_dao.dart';

// ignore_for_file: type=lint
mixin _$FinanceDaoMixin on DatabaseAccessor<LocalDatabase> {
  $FinDirectionsTable get finDirections => attachedDatabase.finDirections;
  $FinAllocationKeysTable get finAllocationKeys =>
      attachedDatabase.finAllocationKeys;
  $FinAllocationPeriodsTable get finAllocationPeriods =>
      attachedDatabase.finAllocationPeriods;
  $EmployeesTable get employees => attachedDatabase.employees;
  $FinAccountsTable get finAccounts => attachedDatabase.finAccounts;
  $FinAssetsTable get finAssets => attachedDatabase.finAssets;
  $FinCategoryGroupsTable get finCategoryGroups =>
      attachedDatabase.finCategoryGroups;
  $FinCategoriesTable get finCategories => attachedDatabase.finCategories;
  $CounterpartiesTable get counterparties => attachedDatabase.counterparties;
  $FinDebtsTable get finDebts => attachedDatabase.finDebts;
  $FinOperationsTable get finOperations => attachedDatabase.finOperations;
  $FinPayrollMappingTable get finPayrollMapping =>
      attachedDatabase.finPayrollMapping;
  $FinPlansTable get finPlans => attachedDatabase.finPlans;
  FinanceDaoManager get managers => FinanceDaoManager(this);
}

class FinanceDaoManager {
  final _$FinanceDaoMixin _db;
  FinanceDaoManager(this._db);
  $$FinDirectionsTableTableManager get finDirections =>
      $$FinDirectionsTableTableManager(_db.attachedDatabase, _db.finDirections);
  $$FinAllocationKeysTableTableManager get finAllocationKeys =>
      $$FinAllocationKeysTableTableManager(
        _db.attachedDatabase,
        _db.finAllocationKeys,
      );
  $$FinAllocationPeriodsTableTableManager get finAllocationPeriods =>
      $$FinAllocationPeriodsTableTableManager(
        _db.attachedDatabase,
        _db.finAllocationPeriods,
      );
  $$EmployeesTableTableManager get employees =>
      $$EmployeesTableTableManager(_db.attachedDatabase, _db.employees);
  $$FinAccountsTableTableManager get finAccounts =>
      $$FinAccountsTableTableManager(_db.attachedDatabase, _db.finAccounts);
  $$FinAssetsTableTableManager get finAssets =>
      $$FinAssetsTableTableManager(_db.attachedDatabase, _db.finAssets);
  $$FinCategoryGroupsTableTableManager get finCategoryGroups =>
      $$FinCategoryGroupsTableTableManager(
        _db.attachedDatabase,
        _db.finCategoryGroups,
      );
  $$FinCategoriesTableTableManager get finCategories =>
      $$FinCategoriesTableTableManager(_db.attachedDatabase, _db.finCategories);
  $$CounterpartiesTableTableManager get counterparties =>
      $$CounterpartiesTableTableManager(
        _db.attachedDatabase,
        _db.counterparties,
      );
  $$FinDebtsTableTableManager get finDebts =>
      $$FinDebtsTableTableManager(_db.attachedDatabase, _db.finDebts);
  $$FinOperationsTableTableManager get finOperations =>
      $$FinOperationsTableTableManager(_db.attachedDatabase, _db.finOperations);
  $$FinPayrollMappingTableTableManager get finPayrollMapping =>
      $$FinPayrollMappingTableTableManager(
        _db.attachedDatabase,
        _db.finPayrollMapping,
      );
  $$FinPlansTableTableManager get finPlans =>
      $$FinPlansTableTableManager(_db.attachedDatabase, _db.finPlans);
}
