// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rates_dao.dart';

// ignore_for_file: type=lint
mixin _$RatesDaoMixin on DatabaseAccessor<LocalDatabase> {
  $EmployeesTable get employees => attachedDatabase.employees;
  $EmployeeRatesTable get employeeRates => attachedDatabase.employeeRates;
  RatesDaoManager get managers => RatesDaoManager(this);
}

class RatesDaoManager {
  final _$RatesDaoMixin _db;
  RatesDaoManager(this._db);
  $$EmployeesTableTableManager get employees =>
      $$EmployeesTableTableManager(_db.attachedDatabase, _db.employees);
  $$EmployeeRatesTableTableManager get employeeRates =>
      $$EmployeeRatesTableTableManager(_db.attachedDatabase, _db.employeeRates);
}
