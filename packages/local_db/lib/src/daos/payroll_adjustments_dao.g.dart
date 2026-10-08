// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payroll_adjustments_dao.dart';

// ignore_for_file: type=lint
mixin _$PayrollAdjustmentsDaoMixin on DatabaseAccessor<LocalDatabase> {
  $EmployeesTable get employees => attachedDatabase.employees;
  $PayrollAdjustmentsTable get payrollAdjustments =>
      attachedDatabase.payrollAdjustments;
  PayrollAdjustmentsDaoManager get managers =>
      PayrollAdjustmentsDaoManager(this);
}

class PayrollAdjustmentsDaoManager {
  final _$PayrollAdjustmentsDaoMixin _db;
  PayrollAdjustmentsDaoManager(this._db);
  $$EmployeesTableTableManager get employees =>
      $$EmployeesTableTableManager(_db.attachedDatabase, _db.employees);
  $$PayrollAdjustmentsTableTableManager get payrollAdjustments =>
      $$PayrollAdjustmentsTableTableManager(
        _db.attachedDatabase,
        _db.payrollAdjustments,
      );
}
