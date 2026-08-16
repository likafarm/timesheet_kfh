// lib/providers/app_provider.dart

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../models/employee_rate.dart';
import '../services/database_service.dart';
import '../services/backup_service.dart';

class AppProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final BackupService _backupService = BackupService();

  DatabaseService get db => _db;
  BackupService get backupService => _backupService;

  // Списки данных
  List<Employee> _employees = [];
  List<TimesheetRecord> _timesheetRecords = [];
  List<Payment> _payments = [];
  List<EmployeeRate> _employeeRates = [];
  List<PayrollResult> _payrollResults = [];
  Map<String, dynamic>? _companySettings;

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
  Map<String, dynamic>? get companySettings => _companySettings;
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
    _companySettings = await _db.getCompanySettings();
    notifyListeners();
  }

  Future<void> updateCompanySettings(Map<String, dynamic> settings) async {
    try {
      await _db.updateCompanySettings(settings);
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
    _employees = await _db.getAllEmployees(activeOnly: activeOnly);
    notifyListeners();
  }

  Future<void> addEmployee(Employee employee, {DateTime? rateStartDate}) async {
    try {
      final id = await _db.insertEmployee(employee);
      final start = rateStartDate ?? employee.hireDate;
      final rate = EmployeeRate(
        employeeId: id,
        baseRate: employee.baseRate,
        fieldRate: employee.fieldRate,
        startDate: start,
      );
      await _db.insertEmployeeRate(rate);
      await loadEmployees();
      setNeedRefreshReports(true);
    } catch (e) {
      _error = 'Ошибка добавления сотрудника: $e';
      notifyListeners();
    }
  }

  Future<void> updateEmployee(Employee employee) async {
    try {
      await _db.updateEmployee(employee);
      await loadEmployees();
      setNeedRefreshReports(true);
    } catch (e) {
      _error = 'Ошибка обновления сотрудника: $e';
      notifyListeners();
    }
  }

  Future<void> deleteEmployee(int id) async {
    try {
      await _db.deleteEmployee(id);
      await loadEmployees();
      setNeedRefreshReports(true);
    } catch (e) {
      _error = 'Ошибка удаления сотрудника: $e';
      notifyListeners();
    }
  }

  Employee? getEmployeeById(int id) {
    try {
      return _employees.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  String getEmployeeName(int id) {
    final emp = getEmployeeById(id);
    return emp?.fullName ?? 'Неизвестно';
  }

  // ==========================================================================
  // EMPLOYEE RATES
  // ==========================================================================

  Future<void> loadEmployeeRates({int? employeeId}) async {
    if (employeeId != null) {
      _employeeRates = await _db.getEmployeeRateHistory(employeeId);
    } else {
      _employeeRates = [];
    }
    notifyListeners();
  }

  Future<void> addEmployeeRate(EmployeeRate rate) async {
    try {
      await _db.insertEmployeeRate(rate);
      await loadEmployeeRates(employeeId: rate.employeeId);
      setNeedRefreshReports(true);
    } catch (e) {
      _error = 'Ошибка добавления ставки: $e';
      notifyListeners();
    }
  }

  Future<EmployeeRate?> getEmployeeRateAtDate(
    int employeeId,
    DateTime date,
  ) async {
    return await _db.getEmployeeRateAtDate(employeeId, date);
  }

  // ==========================================================================
  // TIMESHEET
  // ==========================================================================

  Future<void> loadTimesheet(
    DateTime start,
    DateTime end, {
    int? employeeId,
  }) async {
    _setLoading(true);
    try {
      _currentPeriodStart = start;
      _currentPeriodEnd = end;
      _timesheetRecords = await _db.getTimesheetByPeriod(
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
      final existing = await _db.getTimesheetByPeriod(date, date);
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
          await _db.updateTimesheetRecord(updated);
        } else {
          await _db.insertTimesheetRecord(record);
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
      final existing = await _db.getTimesheetRecord(
        record.employeeId,
        record.date,
      );
      if (existing != null) {
        final updated = existing.copyWith(
          dayType: record.dayType,
          days: record.days,
          workPlace: record.workPlace,
          notes: record.notes,
        );
        await _db.updateTimesheetRecord(updated);
      } else {
        await _db.insertTimesheetRecord(record);
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
      await _db.insertTimesheetRecord(record);
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
      await _db.updateTimesheetRecord(record);
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

  Future<void> deleteTimesheetRecord(int id) async {
    try {
      await _db.deleteTimesheetRecord(id);
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
    return await _db.getTimesheetByPeriod(date, date);
  }

  // ==========================================================================
  // PAYMENTS
  // ==========================================================================

  Future<void> loadAllPayments({DateTime? startDate, DateTime? endDate}) async {
    _setLoading(true);
    try {
      _payments = await _db.getAllPayments(
        startDate: startDate,
        endDate: endDate,
      );
      _error = null;
    } catch (e) {
      _error = 'Ошибка загрузки выплат: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPaymentsByEmployee(
    int employeeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _setLoading(true);
    try {
      _payments = await _db.getPaymentsByEmployee(
        employeeId,
        startDate: startDate,
        endDate: endDate,
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
      await _db.insertPayment(payment);
      notifyListeners();
      setNeedRefreshReports(true);
    } catch (e) {
      _error = 'Ошибка добавления выплаты: $e';
      notifyListeners();
    }
  }

  Future<void> updatePayment(Payment payment) async {
    try {
      await _db.updatePayment(payment);
      notifyListeners();
      setNeedRefreshReports(true);
    } catch (e) {
      _error = 'Ошибка обновления выплаты: $e';
      notifyListeners();
    }
  }

  Future<void> deletePayment(int id, int employeeId) async {
    try {
      await _db.deletePayment(id);
      notifyListeners();
      setNeedRefreshReports(true);
    } catch (e) {
      _error = 'Ошибка удаления выплаты: $e';
      notifyListeners();
    }
  }

  // ==========================================================================
  // ОТЧЁТЫ
  // ==========================================================================

  Future<Map<String, dynamic>> calculateMonthlySalary(
    int employeeId,
    int year,
    int month,
  ) async {
    return await _db.calculateMonthlySalary(employeeId, year, month);
  }

  // ==========================================================================
  // PAYROLL
  // ==========================================================================

  Future<void> loadPayrollResultsForMonth(int year, int month) async {
    _setLoading(true);
    try {
      _payrollResults = await _db.getPayrollResultsForMonth(year, month);
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
      final employees = await _db.getAllEmployees(activeOnly: false);
      for (var emp in employees) {
        if (emp.id == null) continue;
        final data = await _db.calculateMonthlySalaryDetailed(
          emp.id!,
          year,
          month,
        );
        final result = PayrollResult(
          employeeId: emp.id!,
          year: year,
          month: month,
          baseDays: data['baseDays'],
          fieldDays: data['fieldDays'],
          sickDays: data['sickDays'],
          vacationDays: data['vacationDays'],
          totalSalary: data['totalSalary'],
          baseRateUsed: data['baseRateUsed'],
          fieldRateUsed: data['fieldRateUsed'],
          calculatedAt: DateTime.now(),
          status: 'calculated',
        );
        await _db.savePayrollResult(result);
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

  Future<bool> isPayrollUpToDate(int employeeId, int year, int month) async {
    final result = await _db.getPayrollResult(employeeId, year, month);
    if (result == null) return false;
    final currentData = await _db.calculateMonthlySalaryDetailed(
      employeeId,
      year,
      month,
    );
    const epsilon = 0.001;
    return (result.baseDays - currentData['baseDays']).abs() < epsilon &&
        (result.fieldDays - currentData['fieldDays']).abs() < epsilon &&
        (result.sickDays - currentData['sickDays']).abs() < epsilon &&
        (result.vacationDays - currentData['vacationDays']).abs() < epsilon &&
        (result.totalSalary - currentData['totalSalary']).abs() < epsilon;
  }

  Future<Map<String, dynamic>> calculateSingleEmployeePayroll(
    int employeeId,
    int year,
    int month,
  ) async {
    return await _db.calculateMonthlySalaryDetailed(employeeId, year, month);
  }

  Future<void> recalculateSingleEmployee(
    int employeeId,
    int year,
    int month,
  ) async {
    final data = await _db.calculateMonthlySalaryDetailed(
      employeeId,
      year,
      month,
    );
    final result = PayrollResult(
      employeeId: employeeId,
      year: year,
      month: month,
      baseDays: data['baseDays'],
      fieldDays: data['fieldDays'],
      sickDays: data['sickDays'],
      vacationDays: data['vacationDays'],
      totalSalary: data['totalSalary'],
      baseRateUsed: data['baseRateUsed'],
      fieldRateUsed: data['fieldRateUsed'],
      calculatedAt: DateTime.now(),
      status: 'calculated',
    );
    await _db.savePayrollResult(result);
    setNeedRefreshReports(true);
  }

  // ==========================================================================
  // РЕЗЕРВНОЕ КОПИРОВАНИЕ
  // ==========================================================================

  Future<String?> createBackup() async {
    try {
      final db = await _db.database;
      return await _backupService.createBackup(db);
    } catch (e) {
      _error = 'Ошибка создания бэкапа: $e';
      notifyListeners();
      return null;
    }
  }

  Future<List<BackupInfo>> getBackups() async {
    return await _backupService.getBackups();
  }

  Future<bool> restoreFullBackup(String backupPath) async {
    try {
      final db = await _db.database;
      final success = await _backupService.restoreFullBackup(backupPath, db);
      if (success) {
        await _db.close();
        await loadAllData();
      }
      return success;
    } catch (e) {
      _error = 'Ошибка восстановления: $e';
      notifyListeners();
      return false;
    }
  }

  Future<int> restoreTables(String backupPath, List<String> tableNames) async {
    try {
      final db = await _db.database;
      final count = await _backupService.restoreTables(
        backupPath,
        db,
        tableNames,
      );
      await loadAllData();
      return count;
    } catch (e) {
      _error = 'Ошибка восстановления таблиц: $e';
      notifyListeners();
      return 0;
    }
  }

  Future<void> deleteBackup(String path) async {
    try {
      await _backupService.deleteBackup(path);
    } catch (e) {
      _error = 'Ошибка удаления бэкапа: $e';
      notifyListeners();
    }
  }

  // Новый метод для восстановления выбранных записей
  Future<int> restoreSelectedRows(
    String backupPath,
    String tableName,
    List<int> rowIds,
  ) async {
    try {
      final db = await _db.database;
      final count = await _backupService.restoreSelectedRows(
        backupPath,
        db,
        tableName,
        rowIds,
      );
      await loadAllData();
      return count;
    } catch (e) {
      _error = 'Ошибка восстановления записей: $e';
      notifyListeners();
      return 0;
    }
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
