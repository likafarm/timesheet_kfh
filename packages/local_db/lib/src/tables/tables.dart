// Схема v2 локальной базы.
//
// Бизнес-таблицы: ключ `uuid` (UUID v7) и служебные поля синхронизации.
// Даты дней (табель, ставки, выплаты) — строки ISO `гггг-мм-дд`, как в
// старой базе; `created_at`/`calculated_at` переносятся из старой базы как
// есть. `updated_at`/`remote_updated_at` — момент времени в UTC.
//
// Записи не удаляются физически: `deleted = 1` (мягкое удаление), поэтому
// уникальные индексы действуют только среди неудалённых строк.
//
// Внешние ключи отложенные (проверяются при COMMIT): при синхронизации
// дочерние записи могут прийти раньше сотрудника в той же транзакции.

import 'package:drift/drift.dart';

/// Поля синхронизации, общие для всех бизнес-таблиц.
mixin SyncColumns on Table {
  TextColumn get uuid => text()();

  /// `id` строки в старой базе v8 — для сверки после переноса.
  IntColumn get legacyId => integer().nullable()();

  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// Кто изменил запись последним: пока — id устройства.
  TextColumn get editedBy => text().nullable()();

  /// `updated_at` версии, полученной с сервера (этап 3).
  DateTimeColumn get remoteUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {uuid};
}

@DataClassName('CompanySettingsRow')
class CompanySettings extends Table with SyncColumns {
  @override
  String get tableName => 'company_settings';

  TextColumn get companyName => text().withDefault(const Constant('КФХ'))();
  TextColumn get directorName => text().nullable()();
  TextColumn get inn => text().nullable()();
  TextColumn get ogrn => text().nullable()();
  TextColumn get bankAccount => text().nullable()();
  TextColumn get bankName => text().nullable()();
  TextColumn get legalAddress => text().nullable()();
  TextColumn get phone => text().nullable()();
  RealColumn get defaultWorkDayHours =>
      real().withDefault(const Constant(8.0))();
  RealColumn get overtimeMultiplier =>
      real().withDefault(const Constant(1.5))();
  RealColumn get nightShiftMultiplier =>
      real().withDefault(const Constant(1.2))();
}

@DataClassName('EmployeeRow')
@TableIndex(name: 'idx_employees_full_name', columns: {#fullName})
class Employees extends Table with SyncColumns {
  TextColumn get fullName => text()();
  TextColumn get position => text()();
  TextColumn get hireDate => text()();
  TextColumn get dismissalDate => text().nullable()();
  RealColumn get baseRate => real().withDefault(const Constant(0.0))();
  RealColumn get fieldRate => real().withDefault(const Constant(0.0))();
}

@DataClassName('EmployeeRateRow')
@TableIndex(
  name: 'idx_employee_rates_employee',
  columns: {#employeeUuid, #startDate},
)
class EmployeeRates extends Table with SyncColumns {
  TextColumn get employeeUuid =>
      text().references(Employees, #uuid, initiallyDeferred: true)();
  RealColumn get baseRate => real()();
  RealColumn get fieldRate => real()();
  TextColumn get startDate => text()();
  TextColumn get endDate => text().nullable()();
}

@DataClassName('TimesheetRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_timesheet_unique '
  'ON timesheet (employee_uuid, date) WHERE deleted = 0',
)
@TableIndex(name: 'idx_timesheet_date', columns: {#date})
class Timesheet extends Table with SyncColumns {
  @override
  String get tableName => 'timesheet';

  TextColumn get employeeUuid =>
      text().references(Employees, #uuid, initiallyDeferred: true)();
  TextColumn get date => text()();

  /// `work` | `sick` | `vacation` | `dayoff`
  TextColumn get dayType => text().withDefault(const Constant('work'))();

  /// Для `work` — 1 или 0.5.
  RealColumn get days => real().withDefault(const Constant(0.0))();

  /// `base` | `field` (только для `work`).
  TextColumn get workPlace => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
}

@DataClassName('PaymentRow')
@TableIndex(
  name: 'idx_payments_employee_date',
  columns: {#employeeUuid, #paymentDate},
)
@TableIndex(name: 'idx_payments_date', columns: {#paymentDate})
class Payments extends Table with SyncColumns {
  TextColumn get employeeUuid =>
      text().references(Employees, #uuid, initiallyDeferred: true)();
  TextColumn get paymentDate => text()();
  RealColumn get amount => real()();
  TextColumn get paymentType => text().withDefault(const Constant('salary'))();
  TextColumn get periodStart => text().nullable()();
  TextColumn get periodEnd => text().nullable()();
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get documentNumber => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
}

@DataClassName('SickLeaveRow')
@TableIndex(name: 'idx_sick_leave_employee', columns: {#employeeUuid})
class SickLeave extends Table with SyncColumns {
  @override
  String get tableName => 'sick_leave';

  TextColumn get employeeUuid =>
      text().references(Employees, #uuid, initiallyDeferred: true)();
  TextColumn get startDate => text()();
  TextColumn get endDate => text()();
  TextColumn get documentNumber => text().nullable()();
  IntColumn get daysCount => integer()();
  RealColumn get paidByEmployer => real().nullable()();
  RealColumn get paidByFss => real().nullable()();
  TextColumn get notes => text().nullable()();
}

@DataClassName('VacationRow')
@TableIndex(name: 'idx_vacation_employee', columns: {#employeeUuid})
class Vacation extends Table with SyncColumns {
  @override
  String get tableName => 'vacation';

  TextColumn get employeeUuid =>
      text().references(Employees, #uuid, initiallyDeferred: true)();
  TextColumn get startDate => text()();
  TextColumn get endDate => text()();
  TextColumn get vacationType => text().withDefault(const Constant('annual'))();
  IntColumn get daysCount => integer()();
  BoolColumn get isApproved => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
}

@DataClassName('PayrollResultRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_payroll_unique '
  'ON payroll_results (employee_uuid, year, month) WHERE deleted = 0',
)
@TableIndex(name: 'idx_payroll_period', columns: {#year, #month})
class PayrollResults extends Table with SyncColumns {
  TextColumn get employeeUuid =>
      text().references(Employees, #uuid, initiallyDeferred: true)();
  IntColumn get year => integer()();
  IntColumn get month => integer()();
  RealColumn get baseDays => real().withDefault(const Constant(0.0))();
  RealColumn get fieldDays => real().withDefault(const Constant(0.0))();
  RealColumn get sickDays => real().withDefault(const Constant(0.0))();
  RealColumn get vacationDays => real().withDefault(const Constant(0.0))();
  RealColumn get totalSalary => real().withDefault(const Constant(0.0))();
  RealColumn get baseRateUsed => real().nullable()();
  RealColumn get fieldRateUsed => real().nullable()();
  TextColumn get calculatedAt => text()();

  /// `calculated` | `verified` | `discrepancy`
  TextColumn get status => text().withDefault(const Constant('calculated'))();
  IntColumn get skippedWorkDays => integer().withDefault(const Constant(0))();
}

/// Исходящая очередь синхронизации. Наполняется с этапа 3.
@DataClassName('PendingChangeRow')
class PendingChanges extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityTable => text()();
  TextColumn get entityUuid => text()();

  /// `upsert` | `delete`
  TextColumn get operation => text()();

  /// Снимок записи в JSON на момент изменения.
  TextColumn get payload => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}

/// Служебные значения «ключ — значение»: id устройства, курсор pull и т.п.
@DataClassName('SyncStateRow')
class SyncState extends Table {
  @override
  String get tableName => 'sync_state';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
