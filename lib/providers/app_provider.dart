// lib/providers/app_provider.dart

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../models/employee_rate.dart';
import '../services/database_service.dart';

class AppProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  DatabaseService get db => _db;

  List<Employee> _employees = [];
  List<TimesheetRecord> _timesheetRecords = [];
  List<Payment> _payments = [];
  List<EmployeeRate> _employeeRates = [];
  Map<String, dynamic>? _companySettings;

  bool _isLoading = false;
  String? _error;

  DateTime? _currentPeriodStart;
  DateTime? _currentPeriodEnd;

  List<Employee> get employees => _employees;
  List<TimesheetRecord> get timesheetRecords => _timesheetRecords;
  List<Payment> get payments => _payments;
  List<EmployeeRate> get employeeRates => _employeeRates;
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

  /// Добавление сотрудника с указанием даты начала действия ставки
  Future<void> addEmployee(Employee employee, {DateTime? rateStartDate}) async {
    try {
      final id = await _db.insertEmployee(employee);
      // Создаём ставку с указанной датой начала (по умолчанию – дата приёма)
      final start = rateStartDate ?? employee.hireDate;
      final rate = EmployeeRate(
        employeeId: id,
        baseRate: employee.baseRate,
        fieldRate: employee.fieldRate,
        startDate: start,
      );
      await _db.insertEmployeeRate(rate);
      await loadEmployees();
    } catch (e) {
      _error = 'Ошибка добавления сотрудника: $e';
      notifyListeners();
    }
  }

  Future<void> updateEmployee(Employee employee) async {
    try {
      await _db.updateEmployee(employee);
      await loadEmployees();
    } catch (e) {
      _error = 'Ошибка обновления сотрудника: $e';
      notifyListeners();
    }
  }

  Future<void> deleteEmployee(int id) async {
    try {
      await _db.deleteEmployee(id);
      await loadEmployees();
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
  // EMPLOYEE RATES (история ставок)
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
    } catch (e) {
      _error = 'Ошибка добавления выплаты: $e';
      notifyListeners();
    }
  }

  Future<void> updatePayment(Payment payment) async {
    try {
      await _db.updatePayment(payment);
      notifyListeners();
    } catch (e) {
      _error = 'Ошибка обновления выплаты: $e';
      notifyListeners();
    }
  }

  Future<void> deletePayment(int id, int employeeId) async {
    try {
      await _db.deletePayment(id);
      notifyListeners();
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
