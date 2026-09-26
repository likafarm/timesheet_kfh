// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timesheet_dao.dart';

// ignore_for_file: type=lint
mixin _$TimesheetDaoMixin on DatabaseAccessor<LocalDatabase> {
  $EmployeesTable get employees => attachedDatabase.employees;
  $TimesheetTable get timesheet => attachedDatabase.timesheet;
  TimesheetDaoManager get managers => TimesheetDaoManager(this);
}

class TimesheetDaoManager {
  final _$TimesheetDaoMixin _db;
  TimesheetDaoManager(this._db);
  $$EmployeesTableTableManager get employees =>
      $$EmployeesTableTableManager(_db.attachedDatabase, _db.employees);
  $$TimesheetTableTableManager get timesheet =>
      $$TimesheetTableTableManager(_db.attachedDatabase, _db.timesheet);
}
