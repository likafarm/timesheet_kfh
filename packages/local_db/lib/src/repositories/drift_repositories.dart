// Реализация репозиториев домена на drift: преобразование строк базы
// в доменные модели и обратно. Вся логика запросов — в DAO.

import 'package:drift/drift.dart';
import 'package:kfh_domain/kfh_domain.dart';

import '../database.dart';

/// Все репозитории над одной базой.
class DriftRepositories {
  final LocalDatabase db;

  DriftRepositories(this.db);

  late final EmployeeRepository employees = DriftEmployeeRepository(db);
  late final RateRepository rates = DriftRateRepository(db);
  late final TimesheetRepository timesheet = DriftTimesheetRepository(db);
  late final PaymentRepository payments = DriftPaymentRepository(db);
  late final PayrollRepository payroll = DriftPayrollRepository(db);
  late final SettingsRepository settings = DriftSettingsRepository(db);

  late final PayrollService payrollService = PayrollService(
    employees: employees,
    rates: rates,
    timesheet: timesheet,
    payments: payments,
    payroll: payroll,
  );
}

String _requireId(String? id, String what) {
  if (id == null) throw ArgumentError('$what без id');
  return id;
}

// ---------------------------------------------------------------------------

class DriftEmployeeRepository implements EmployeeRepository {
  final LocalDatabase _db;
  DriftEmployeeRepository(this._db);

  static Employee _fromRow(EmployeeRow r) => Employee(
    id: r.uuid,
    fullName: r.fullName,
    position: r.position,
    hireDate: parseDateIso(r.hireDate),
    dismissalDate: parseDateIsoOrNull(r.dismissalDate),
    baseRate: r.baseRate,
    fieldRate: r.fieldRate,
  );

  static EmployeesCompanion _toCompanion(Employee e) => EmployeesCompanion(
    fullName: Value(e.fullName),
    position: Value(e.position),
    hireDate: Value(formatDateIso(e.hireDate)),
    dismissalDate: Value(formatDateIsoOrNull(e.dismissalDate)),
    baseRate: Value(e.baseRate),
    fieldRate: Value(e.fieldRate),
  );

  @override
  Future<List<Employee>> all({DateTime? activeOn}) async =>
      (await _db.employeesDao.allEmployees(
        activeOn: activeOn,
      )).map(_fromRow).toList();

  @override
  Future<Employee?> byId(String id) async {
    final row = await _db.employeesDao.employeeByUuid(id);
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<String> add(Employee employee) =>
      _db.employeesDao.insertEmployee(_toCompanion(employee));

  @override
  Future<void> update(Employee employee) => _db.employeesDao.updateEmployee(
    _requireId(employee.id, 'Сотрудник'),
    _toCompanion(employee),
  );

  @override
  Future<void> delete(String id) => _db.employeesDao.softDeleteEmployee(id);
}

// ---------------------------------------------------------------------------

class DriftRateRepository implements RateRepository {
  final LocalDatabase _db;
  DriftRateRepository(this._db);

  static EmployeeRate _fromRow(EmployeeRateRow r) => EmployeeRate(
    id: r.uuid,
    employeeId: r.employeeUuid,
    baseRate: r.baseRate,
    fieldRate: r.fieldRate,
    startDate: parseDateIso(r.startDate),
    endDate: parseDateIsoOrNull(r.endDate),
  );

  @override
  Future<String> add(EmployeeRate rate) => _db.ratesDao.addRate(
    employeeUuid: rate.employeeId,
    baseRate: rate.baseRate,
    fieldRate: rate.fieldRate,
    startDate: rate.startDate,
  );

  @override
  Future<List<EmployeeRate>> history(String employeeId) async =>
      (await _db.ratesDao.rateHistory(employeeId)).map(_fromRow).toList();

  @override
  Future<EmployeeRate?> at(String employeeId, DateTime date) async {
    final row = await _db.ratesDao.rateAt(employeeId, date);
    return row == null ? null : _fromRow(row);
  }
}

// ---------------------------------------------------------------------------

class DriftTimesheetRepository implements TimesheetRepository {
  final LocalDatabase _db;
  DriftTimesheetRepository(this._db);

  static TimesheetRecord _fromRow(TimesheetRow r) => TimesheetRecord(
    id: r.uuid,
    employeeId: r.employeeUuid,
    date: parseDateIso(r.date),
    dayType: r.dayType,
    days: r.days,
    workPlace: r.workPlace,
    notes: r.notes,
    createdAt: DateTime.parse(r.createdAt),
  );

  static TimesheetCompanion _toCompanion(TimesheetRecord t) =>
      TimesheetCompanion(
        employeeUuid: Value(t.employeeId),
        date: Value(formatDateIso(t.date)),
        dayType: Value(t.dayType),
        days: Value(t.days),
        workPlace: Value(t.workPlace),
        notes: Value(t.notes),
      );

  @override
  Future<String> add(TimesheetRecord record) =>
      _db.timesheetDao.insertRecord(_toCompanion(record));

  @override
  Future<void> update(TimesheetRecord record) => _db.timesheetDao.updateRecord(
    _requireId(record.id, 'Запись табеля'),
    _toCompanion(record),
  );

  @override
  Future<void> delete(String id) => _db.timesheetDao.softDeleteRecord(id);

  @override
  Future<TimesheetRecord?> on(String employeeId, DateTime date) async {
    final row = await _db.timesheetDao.recordOn(employeeId, date);
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<List<TimesheetRecord>> inPeriod(
    DateTime start,
    DateTime end, {
    String? employeeId,
  }) async => (await _db.timesheetDao.recordsInPeriod(
    start,
    end,
    employeeUuid: employeeId,
  )).map(_fromRow).toList();
}

// ---------------------------------------------------------------------------

class DriftPaymentRepository implements PaymentRepository {
  final LocalDatabase _db;
  DriftPaymentRepository(this._db);

  static Payment _fromRow(PaymentRow r) => Payment(
    id: r.uuid,
    employeeId: r.employeeUuid,
    paymentDate: parseDateIso(r.paymentDate),
    amount: r.amount,
    paymentType: r.paymentType,
    periodStart: r.periodStart,
    periodEnd: r.periodEnd,
    paymentMethod: r.paymentMethod,
    documentNumber: r.documentNumber,
    notes: r.notes,
    createdAt: DateTime.parse(r.createdAt),
  );

  static PaymentsCompanion _toCompanion(Payment p) => PaymentsCompanion(
    employeeUuid: Value(p.employeeId),
    paymentDate: Value(formatDateIso(p.paymentDate)),
    amount: Value(p.amount),
    paymentType: Value(p.paymentType),
    periodStart: Value(dateOnlyString(p.periodStart)),
    periodEnd: Value(dateOnlyString(p.periodEnd)),
    paymentMethod: Value(p.paymentMethod),
    documentNumber: Value(p.documentNumber),
    notes: Value(p.notes),
  );

  @override
  Future<String> add(Payment payment) =>
      _db.paymentsDao.insertPayment(_toCompanion(payment));

  @override
  Future<void> update(Payment payment) => _db.paymentsDao.updatePayment(
    _requireId(payment.id, 'Выплата'),
    _toCompanion(payment),
  );

  @override
  Future<void> delete(String id) => _db.paymentsDao.softDeletePayment(id);

  @override
  Future<List<Payment>> list({
    String? employeeId,
    DateTime? start,
    DateTime? end,
  }) async => (await _db.paymentsDao.paymentsList(
    employeeUuid: employeeId,
    start: start,
    end: end,
  )).map(_fromRow).toList();

  @override
  Future<Map<String, double>> paidBefore(DateTime date) =>
      _db.paymentsDao.paidBefore(date);
}

// ---------------------------------------------------------------------------

class DriftPayrollRepository implements PayrollRepository {
  final LocalDatabase _db;
  DriftPayrollRepository(this._db);

  static PayrollResult _fromRow(PayrollResultRow r) => PayrollResult(
    id: r.uuid,
    employeeId: r.employeeUuid,
    year: r.year,
    month: r.month,
    baseDays: r.baseDays,
    fieldDays: r.fieldDays,
    sickDays: r.sickDays,
    vacationDays: r.vacationDays,
    totalSalary: r.totalSalary,
    baseRateUsed: r.baseRateUsed,
    fieldRateUsed: r.fieldRateUsed,
    calculatedAt: DateTime.parse(r.calculatedAt),
    status: r.status,
    skippedWorkDays: r.skippedWorkDays,
  );

  @override
  Future<String> save(PayrollResult r) => _db.payrollDao.saveResult(
    PayrollResultsCompanion(
      employeeUuid: Value(r.employeeId),
      year: Value(r.year),
      month: Value(r.month),
      baseDays: Value(r.baseDays),
      fieldDays: Value(r.fieldDays),
      sickDays: Value(r.sickDays),
      vacationDays: Value(r.vacationDays),
      totalSalary: Value(r.totalSalary),
      baseRateUsed: Value(r.baseRateUsed),
      fieldRateUsed: Value(r.fieldRateUsed),
      calculatedAt: Value(r.calculatedAt.toIso8601String()),
      status: Value(r.status),
      skippedWorkDays: Value(r.skippedWorkDays),
    ),
  );

  @override
  Future<PayrollResult?> resultFor(
    String employeeId,
    int year,
    int month,
  ) async {
    final row = await _db.payrollDao.resultFor(employeeId, year, month);
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<List<PayrollResult>> forMonth(int year, int month) async =>
      (await _db.payrollDao.resultsForMonth(
        year,
        month,
      )).map(_fromRow).toList();

  @override
  Future<Map<String, double>> accruedBefore(int year, int month) =>
      _db.payrollDao.accruedBefore(year, month);
}

// ---------------------------------------------------------------------------

class DriftSettingsRepository implements SettingsRepository {
  final LocalDatabase _db;
  DriftSettingsRepository(this._db);

  @override
  Future<CompanySettings> get() async {
    final r = await _db.settingsDao.getSettings();
    if (r == null) throw StateError('В базе нет настроек хозяйства');
    return CompanySettings(
      id: r.uuid,
      companyName: r.companyName,
      directorName: r.directorName,
      inn: r.inn,
      ogrn: r.ogrn,
      bankAccount: r.bankAccount,
      bankName: r.bankName,
      legalAddress: r.legalAddress,
      phone: r.phone,
      defaultWorkDayHours: r.defaultWorkDayHours,
      overtimeMultiplier: r.overtimeMultiplier,
      nightShiftMultiplier: r.nightShiftMultiplier,
    );
  }

  @override
  Future<void> save(CompanySettings s) => _db.settingsDao.updateSettings(
    CompanySettingsCompanion(
      companyName: Value(s.companyName),
      directorName: Value(s.directorName),
      inn: Value(s.inn),
      ogrn: Value(s.ogrn),
      bankAccount: Value(s.bankAccount),
      bankName: Value(s.bankName),
      legalAddress: Value(s.legalAddress),
      phone: Value(s.phone),
      defaultWorkDayHours: Value(s.defaultWorkDayHours),
      overtimeMultiplier: Value(s.overtimeMultiplier),
      nightShiftMultiplier: Value(s.nightShiftMultiplier),
    ),
  );
}
