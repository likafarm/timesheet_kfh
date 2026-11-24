// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_dao.dart';

// ignore_for_file: type=lint
mixin _$SalesDaoMixin on DatabaseAccessor<LocalDatabase> {
  $ProductGroupsTable get productGroups => attachedDatabase.productGroups;
  $ProductsTable get products => attachedDatabase.products;
  $ProductPricesTable get productPrices => attachedDatabase.productPrices;
  $EmployeesTable get employees => attachedDatabase.employees;
  $CounterpartiesTable get counterparties => attachedDatabase.counterparties;
  $CustomersTable get customers => attachedDatabase.customers;
  SalesDaoManager get managers => SalesDaoManager(this);
}

class SalesDaoManager {
  final _$SalesDaoMixin _db;
  SalesDaoManager(this._db);
  $$ProductGroupsTableTableManager get productGroups =>
      $$ProductGroupsTableTableManager(_db.attachedDatabase, _db.productGroups);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$ProductPricesTableTableManager get productPrices =>
      $$ProductPricesTableTableManager(_db.attachedDatabase, _db.productPrices);
  $$EmployeesTableTableManager get employees =>
      $$EmployeesTableTableManager(_db.attachedDatabase, _db.employees);
  $$CounterpartiesTableTableManager get counterparties =>
      $$CounterpartiesTableTableManager(
        _db.attachedDatabase,
        _db.counterparties,
      );
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db.attachedDatabase, _db.customers);
}
