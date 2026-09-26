// lib/providers/app_provider.dart

import 'package:flutter/material.dart';
import 'package:kfh_domain/kfh_domain.dart';
import '../services/app_database.dart';
import '../services/backup_service.dart';

class AppProvider extends ChangeNotifier {
  AppProvider(this._appDb);

  final AppDatabase _appDb;
  final BackupService _backupService = BackupService();

  BackupService get backupService => _backupService;

  /// Путь к файлу базы (для «О программе»).
  String get databasePath => _appDb.path;

  EmployeeRepository get _employeesRepo => _appDb.repos.employees;
  RateRepository get _ratesRepo => _appDb.repos.rates;
  TimesheetRepository get _timesheetRepo => _appDb.repos.timesheet;
  PaymentRepository get _paymentsRepo => _appDb.repos.payments;
  PayrollRepository get _payrollRepo => _appDb.repos.payroll;
  SettingsRepository get _settingsRepo => _appDb.repos.settings;
  PayrollService get _payrollService => _appDb.repos.payrollService;

  // Списки данных
  List<Employee> _employees = [];
  List<TimesheetRecord> _timesheetRecords = [];
  List<Payment> _payments = [];
  List<EmployeeRate> _employeeRates = [];
  List<PayrollResult> _payrollResults = [];
  Map<String, double> _startingBalances = {};
  CompanySettings? _companySettings;

  // Состояние загрузки
  bool _isLoading = false;
  String? _error;

  // Для перезагрузки табеля
  DateTime? _currentPeriodStart;
  DateTime? _currentPeriodEnd;

  // Флаг для обновления отчётов
  bool _needRefreshReports = false;
  bool get needRefreshReports => _needRefreshReports;

  void setNeedRefreshReports(bool value) {
    if (_needRefreshReports != value) {
      _needRefreshReports = value;
      notifyListeners();
    }
  }

  // Геттеры
  List<Employee> get employees => _employees;
  List<TimesheetRecord> get timesheetRecords => _timesheetRecords;
  List<Payment> get payments => _payments;
  List<EmployeeRate> get employeeRates => _employeeRates;
  List<PayrollResult> get payrollResults => _payrollResults;
  Map<String, double> get startingBalances => _startingBalances;
  CompanySettings? get companySettings => _companySettings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ==========================================================================
  // ЗАГРУЗКА ДАННЫХ
  // ==========================================================================

  Future<void> loadAllData() async {
    _setLoading(true);
    try {
      await Future.wait([loadEmployees(), loadCompanySettings()]);
      _error = null;
    } catch (e) {
      _error = 'Ошибка загрузки данных: $e';
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================================
  // COMPANY SETTINGS
  // ==========================================================================

  Future<void> loadCompanySettings() async {
    _companySettings = await _settingsRepo.get();
    notifyListeners();
  }

  Future<void> updateCompanySettings(CompanySettings settings) async {
    try {
      await _settingsRepo.save(settings);
      await loadCompanySettings();
    } catch (e) {
      _error = 'Ошибка обновления настроек: $e';
      notifyListeners();
    }
  }

  // ==========================================================================
  // EMPLOYEES
  // ==========================================================================

  Future<void> loadEmployees({bool activeOnly = false}) async {
    _employees = await _employeesRepo.all(
      activeOn: activeOnly ? DateTime.now() : null,
    );
    notifyListeners();
  }

  Future<void> addEmployee(Employee employee, {DateTime? rateStartDate}) async {
    try {
      final id = await _employeesRepo.add(employee);
      final start = rateStartDate ?? employee.hireDate;
      final rate = EmployeeRate(
        employeeId: id,
        baseRate: employee.baseRate,
        fieldRate: employee.fieldRate,
        startDate: start,
      );
      await _ratesRepo.add(rate);
      await loadEmployees();
      setNeedRefreshReports(true);
    } catch (e) {
      _error = 'Ошибка добавления сотрудника: $e';
      notifyListeners();
    }
  }

  Future<void> updateEmployee(Employee employee) async {
    try {
      await _employeesRepo.update(employee);
      await loadEmployees();
      setNeedRefreshReports(true);
    } catch (e) {
      _error = 'Ошибка обновления сотрудника: $e';
      notifyListeners();
    }
  }

  Employee? getEmployeeById(String id) {
    try {
      return _employees.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  String getEmployeeName(String id) {
    final emp = getEmployeeById(id);
    return emp?.fullName ?? 'Неизвестно';
  }

  // ==========================================================================
  // EMPLOYEE RATES
  // ==========================================================================

  Future<void> loadEmployeeRates({String? employeeId}) async {
    if (employeeId != null) {
      _employeeRates = await _ratesRepo.history(employeeId);
    } else {
      _employeeRates = [];
    }
    notifyListeners();
  }

  Future<void> addEmployeeRate(EmployeeRate rate) async {
    try {
      await _ratesRepo.add(rate);
      await loadEmployeeRates(employeeId: rate.employeeId);
      setNeedRefreshReports(true);
    } catch (e) {
      _error = 'Ошибка добавления ставки: $e';
      notifyListeners();
    }
  }

  Future<EmployeeRate?> getEmployeeRateAtDate(
    String employeeId,
    DateTime date,
  ) async {
    return await _ratesRepo.at(employeeId, date);
  }

  // ==========================================================================
  // TIMESHEET
  // ==========================================================================

  Future<void> loadTimesheet(
    DateTime start,
    DateTime end, {
    String? employeeId,
  }) async {
    _setLoading(true);
    try {
      _currentPeriodStart = start;
      _currentPeriodEnd = end;
      _timesheetRecords = await _timesheetRepo.inPeriod(
        start,
        end,
        employeeId: employeeId,
      );
      _error = null;
    } catch (e) {
      _error = 'Ошибка загрузки табеля: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> saveDailyTimesheet(
    List<TimesheetRecord> records,
    DateTime date,
  ) async {
    try {
      final existing = await _timesheetRepo.inPeriod(date, date);
      for (var record in records) {
        TimesheetRecord? existingRecord;
        for (var r in existing) {
          if (r.employeeId == record.employeeId) {
            existingRecord = r;
            break;
          }
        }
        if (existingRecord != null) {
          final updated = existingRecord.copyWith(
            dayType: record.dayType,
            days: record.days,
            workPlace: record.workPlace,
            notes: record.notes,
          );
          await _timesheetRepo.update(updated);
        } else {
          await _timesheetRepo.add(record);
        }
      }
      if (_currentPeriodStart != null && _currentPeriodEnd != null) {
        await loadTimesheet(_currentPeriodStart!, _currentPeriodEnd!);
      } else {
        notifyListeners();
      }
      setNeedRefreshReports(true);
    } catch (e) {
      _error = 'Ошибка сохранения за день: $e';
      notifyListeners();
    }
  }

  Future<void> saveTimesheetRecord(TimesheetRecord record) async {
    try {
      final existing = await _timesheetRepo.on(record.employeeId, record.date);
      if (existing != null) {
        final updated = existing.copyWith(
          dayType: record.dayType,
          days: record.days,
          workPlace: record.workPlace,
          notes: record.notes,
        );
        await _timesheetRepo.update(updated);
      } else {
        await _timesheetRepo.add(record);
      }
      if (_currentPeriodStart != null && _currentPeriodEnd != null) {
        await loadTimesheet(_currentPeriodStart!, _currentPeriodEnd!);
      } else {
        notifyListeners();
      }
      setNeedRefreshReports(true);
    } catch (e) {
      _error = 'Ошибка сохранения записи: $e';
      notifyListeners();
    }
  }

  Future<void> addTimesheetRecord(TimesheetRecord record) async {
    try {
      final existing = await _timesheetRepo.on(record.employeeId, record.date);
      if (existing != null) {
        _error = 'Запись на эту дату уже есть';
        notifyListeners();
        return;
      }
      await _timesheetRepo.add(record);
      if (_currentPeriodStart != null && _currentPeriodEnd != null) {
        await loadTimesheet(_currentPeriodStart!, _currentPeriodEnd!);
      } else {
        notifyListeners();
      }
      setNeedRefreshReports(true);
    } catch (e) {
      _error = 'Ошибка добавления записи: $e';
      notifyListeners();
    }
  }

  Future<void> updateTimesheetRecord(TimesheetRecord record) async {
    try {
      await _timesheetRepo.update(record);
      if (_currentPeriodStart != null && _currentPeriodEnd != null) {
        await loadTimesheet(_currentPeriodStart!, _currentPeriodEnd!);
      } else {
        notifyListeners();
      }
      setNeedRefreshReports(true);
    } catch (e) {
      _error = 'Ошибка обновления записи: $e';
      notifyListeners();
    }
  }

  Future<void> deleteTimesheetRecord(String id) async {
    try {
      await _timesheetRepo.delete(id);
      if (_currentPeriodStart != null && _currentPeriodEnd != null) {
        await loadTimesheet(_currentPeriodStart!, _currentPeriodEnd!);
      } else {
        notifyListeners();
      }
      setNeedRefreshReports(true);
    } catch (e) {
      _error = 'Ошибка удаления записи: $e';
      notifyListeners();
    }
  }

  Future<List<TimesheetRecord>> getTimesheetForDate(DateTime date) async {
    return await _timesheetRepo.inPeriod(date, date);
  }

  // ==========================================================================
  // PAYMENTS
  // ==========================================================================

  Future<void> loadAllPayments({DateTime? startDate, DateTime? endDate}) async {
    _setLoading(true);
    try {
      _payments = await _paymentsRepo.list(start: startDate, end: endDate);
      _error = null;
    } catch (e) {
      _error = 'Ошибка загрузки выплат: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPaymentsByEmployee(
    String employeeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _setLoading(true);
    try {
      _payments = await _paymentsRepo.list(
        employeeId: employeeId,
        start: startDate,
        end: endDate,
      );
      _error = null;
    } catch (e) {
      _error = 'Ошибка загрузки выплат: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addPayment(Payment payment) async {
    try {
      await _paymentsRepo.add(payment);
      notifyListeners();
      setNeedRefreshReports(true);
    } catch (e) {
      _error = 'Ошибка добавления выплаты: $e';
      notifyListeners();
    }
  }

  Future<void> updatePayment(Payment payment) async {
    try {
      await _paymentsRepo.update(payment);
      notifyListeners();
      setNeedRefreshReports(true);
    } catch (e) {
      _error = 'Ошибка обновления выплаты: $e';
      notifyListeners();
    }
  }

  Future<void> deletePayment(String id, String employeeId) async {
    try {
      await _paymentsRepo.delete(id);
      notifyListeners();
      setNeedRefreshReports(true);
    } catch (e) {
      _error = 'Ошибка удаления выплаты: $e';
      notifyListeners();
    }
  }

  Future<void> loadStartingBalances(int year, int month) async {
    _startingBalances = await _payrollService.startingBalances(
      DateTime(year, month, 1),
    );
    notifyListeners();
  }

  // ==========================================================================
  // ОТЧЁТЫ
  // ==========================================================================

  Future<Map<String, dynamic>> calculateMonthlySalary(
    String employeeId,
    int year,
    int month,
  ) async {
    return (await _payrollService.calculateMonth(
      employeeId,
      year,
      month,
    )).toMap();
  }

  // ==========================================================================
  // PAYROLL
  // ==========================================================================

  Future<void> loadPayrollResultsForMonth(int year, int month) async {
    _setLoading(true);
    try {
      _payrollResults = await _payrollRepo.forMonth(year, month);
      _error = null;
    } catch (e) {
      _error = 'Ошибка загрузки результатов расчёта: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> calculatePayrollForMonth(int year, int month) async {
    _setLoading(true);
    try {
      final employees = await _employeesRepo.all();
      for (var emp in employees) {
        if (emp.id == null) continue;
        final calc = await _payrollService.calculateMonth(emp.id!, year, month);
        await _payrollRepo.save(_payrollFromCalc(calc));
      }
      await loadPayrollResultsForMonth(year, month);
      _error = null;
      setNeedRefreshReports(true);
    } catch (e) {
      _error = 'Ошибка массового расчёта зарплаты: $e';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> isPayrollUpToDate(String employeeId, int year, int month) async {
    final result = await _payrollRepo.resultFor(employeeId, year, month);
    if (result == null) return false;
    final current = await _payrollService.calculateMonth(
      employeeId,
      year,
      month,
    );
    const epsilon = 0.001;
    return (result.baseDays - current.baseDays).abs() < epsilon &&
        (result.fieldDays - current.fieldDays).abs() < epsilon &&
        (result.sickDays - current.sickDays).abs() < epsilon &&
        (result.vacationDays - current.vacationDays).abs() < epsilon &&
        (result.totalSalary - current.totalSalary).abs() < epsilon &&
        result.skippedWorkDays == current.skippedWorkDays;
  }

  Future<Map<String, dynamic>> calculateSingleEmployeePayroll(
    String employeeId,
    int year,
    int month,
  ) async {
    return (await _payrollService.calculateMonth(
      employeeId,
      year,
      month,
    )).toMap();
  }

  Future<void> recalculateSingleEmployee(
    String employeeId,
    int year,
    int month,
  ) async {
    final calc = await _payrollService.calculateMonth(employeeId, year, month);
    await _payrollRepo.save(_payrollFromCalc(calc));
    setNeedRefreshReports(true);
  }

  PayrollResult _payrollFromCalc(PayrollCalculation calc) {
    return PayrollResult(
      employeeId: calc.employeeId,
      year: calc.year,
      month: calc.month,
      baseDays: calc.baseDays,
      fieldDays: calc.fieldDays,
      sickDays: calc.sickDays,
      vacationDays: calc.vacationDays,
      totalSalary: calc.totalSalary,
      baseRateUsed: calc.baseRateUsed,
      fieldRateUsed: calc.fieldRateUsed,
      calculatedAt: DateTime.now(),
      status: 'calculated',
      skippedWorkDays: calc.skippedWorkDays,
    );
  }

  // ==========================================================================
  // РЕЗЕРВНОЕ КОПИРОВАНИЕ
  // ==========================================================================

  Future<String?> createBackup() async {
    try {
      return await _backupService.createBackup(
        _appDb.db,
        type: BackupType.daily,
      );
    } catch (e) {
      _error = 'Ошибка создания бэкапа: $e';
      notifyListeners();
      return null;
    }
  }

  /// Автоматическое резервное копирование при запуске приложения.
  /// - Всегда создаёт (или обновляет) ежедневную копию.
  /// - Всегда пытается создать ежемесячную копию; сервис сам пропустит,
  ///   если за текущий месяц копия уже существует.
  Future<void> autoBackup() async {
    try {
      await _backupService.createBackup(_appDb.db, type: BackupType.daily);
      await _backupService.createBackup(_appDb.db, type: BackupType.monthly);
    } catch (e) {
      // Автобэкап не должен нарушать работу приложения
      debugPrint('autoBackup error: $e');
    }
  }

  Future<List<BackupInfo>> getBackups() async {
    return await _backupService.getBackups();
  }

  Future<void> deleteBackup(String path) async {
    try {
      await _backupService.deleteBackup(path);
    } catch (e) {
      _error = 'Ошибка удаления бэкапа: $e';
      notifyListeners();
    }
  }

  // ==========================================================================
  // ПРОСМОТР БАЗЫ (только чтение)
  // ==========================================================================

  Future<List<String>> getTableNames() async {
    final rows = await _appDb.db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();
    return rows.map((r) => r.read<String>('name')).toList();
  }

  Future<List<Map<String, dynamic>>> getTableData(
    String tableName, {
    int limit = 100,
  }) async {
    if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(tableName)) {
      throw ArgumentError('Недопустимое имя таблицы: $tableName');
    }
    final rows = await _appDb.db
        .customSelect('SELECT * FROM $tableName LIMIT $limit')
        .get();
    return rows.map((r) => r.data).toList();
  }

  // ==========================================================================
  // ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
  // ==========================================================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
