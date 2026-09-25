// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payroll_dao.dart';

// ignore_for_file: type=lint
mixin _$PayrollDaoMixin on DatabaseAccessor<LocalDatabase> {
  $EmployeesTable get employees => attachedDatabase.employees;
  $PayrollResultsTable get payrollResults => attachedDatabase.payrollResults;
  PayrollDaoManager get managers => PayrollDaoManager(this);
}

class PayrollDaoManager {
  final _$PayrollDaoMixin _db;
  PayrollDaoManager(this._db);
  $$EmployeesTableTableManager get employees =>
      $$EmployeesTableTableManager(_db.attachedDatabase, _db.employees);
  $$PayrollResultsTableTableManager get payrollResults =>
      $$PayrollResultsTableTableManager(
        _db.attachedDatabase,
        _db.payrollResults,
      );
}
