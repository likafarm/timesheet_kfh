// lib/providers/app_provider.dart

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../models/employee_rate.dart';
import '../services/database_service.dart';

/// Главный провайдер состояния приложения (упрощённая версия)
class AppProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  // Геттер для доступа к базе данных (для отладки)
  DatabaseService get db => _db;

  // Списки данных
  List<Employee> _employees = [];
  List<TimesheetRecord> _timesheetRecords = [];
  List<Payment> _payments = [];
  List<EmployeeRate> _employeeRates = [];
  Map<String, dynamic>? _companySettings;

  // Состояние загрузки
  bool _isLoading = false;
  String? _error;

  // Для перезагрузки табеля
  DateTime? _currentPeriodStart;
  DateTime? _currentPeriodEnd;

  // Геттеры
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
      await Future.wait([
        loadEmployees(),
        loadEmployeeRates(),
        loadCompanySettings(),
      ]);
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

  Future<void> addEmployee(Employee employee) async {
    try {
      await _db.insertEmployee(employee);
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

  /// Сохранение записей за день (быстрый ввод)
  Future<void> saveDailyTimesheet(
    List<TimesheetRecord> records,
    DateTime date,
  ) async {
    try {
      // Получаем существующие записи за этот день
      final existing = await _db.getTimesheetByPeriod(date, date);
      for (var record in records) {
        // Ищем существующую запись для этого сотрудника
        TimesheetRecord? existingRecord;
        for (var r in existing) {
          if (r.employeeId == record.employeeId) {
            existingRecord = r;
            break;
          }
        }
        if (existingRecord != null) {
          // Обновляем
          final updated = existingRecord.copyWith(
            dayType: record.dayType,
            days: record.days,
            workPlace: record.workPlace,
            notes: record.notes,
          );
          await _db.updateTimesheetRecord(updated);
        } else {
          // Вставляем новую запись
          await _db.insertTimesheetRecord(record);
        }
      }
      // Перезагружаем табель, если есть текущий период
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
      // Не перезагружаем список, только уведомляем об изменении
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
      // Не перезагружаем список, только уведомляем
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
