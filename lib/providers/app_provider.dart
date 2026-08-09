// ignore_for_file: prefer_final_fields

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';

/// Главный провайдер состояния приложения
class AppProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  // Списки данных
  List<Employee> _employees = [];
  List<WorkSite> _workSites = [];
  List<WorkType> _workTypes = [];
  List<Machinery> _machinery = [];
  List<TimesheetRecord> _timesheetRecords = [];
  List<Payment> _payments = [];
  List<Vacation> _vacations = [];
  List<SickLeave> _sickLeaves = [];
  CompanySettings? _companySettings;

  // Графики работы
  List<Map<String, dynamic>> _workScheduleTypes = [];
  Map<int, Map<String, dynamic>> _employeeSchedules =
      {}; // employeeId -> текущий график
  Map<int, List<Map<String, dynamic>>> _scheduleExceptions =
      {}; // employeeId -> список исключений

  // Состояние загрузки
  bool _isLoading = false;
  String? _error;

  // Для перезагрузки табеля
  DateTime? _currentPeriodStart;
  DateTime? _currentPeriodEnd;

  // Геттеры
  List<Employee> get employees => _employees;
  List<WorkSite> get workSites => _workSites;
  List<WorkType> get workTypes => _workTypes;
  List<Machinery> get machinery => _machinery;
  List<TimesheetRecord> get timesheetRecords => _timesheetRecords;
  List<Payment> get payments => _payments;
  List<Vacation> get vacations => _vacations;
  List<SickLeave> get sickLeaves => _sickLeaves;
  CompanySettings? get companySettings => _companySettings;
  List<Map<String, dynamic>> get workScheduleTypes => _workScheduleTypes;
  Map<int, Map<String, dynamic>> get employeeSchedules => _employeeSchedules;
  Map<int, List<Map<String, dynamic>>> get scheduleExceptions =>
      _scheduleExceptions;
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
        loadWorkSites(),
        loadWorkTypes(),
        loadMachinery(),
        loadCompanySettings(),
        loadWorkScheduleTypes(),
      ]);
      await loadAllEmployeeSchedules();
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

  Future<void> updateCompanySettings(CompanySettings settings) async {
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
      await loadEmployeeSchedule(employee.id!);
    } catch (e) {
      _error = 'Ошибка обновления сотрудника: $e';
      notifyListeners();
    }
  }

  Future<void> deleteEmployee(int id) async {
    try {
      await _db.deleteEmployee(id);
      await loadEmployees();
      _employeeSchedules.remove(id);
      _scheduleExceptions.remove(id);
    } catch (e) {
      _error = 'Ошибка удаления сотрудника: $e';
      notifyListeners();
    }
  }

  Future<void> dismissEmployee(
    int id,
    DateTime dismissalDate,
    String reason,
  ) async {
    try {
      final employee = getEmployeeById(id);
      if (employee == null) return;
      final updated = employee.copyWith(
        isActive: false,
        dismissalDate: dismissalDate,
        dismissalReason: reason,
      );
      await _db.updateEmployee(updated);
      await loadEmployees();
    } catch (e) {
      _error = 'Ошибка увольнения: $e';
      notifyListeners();
    }
  }

  Future<void> reinstateEmployee(int id) async {
    try {
      final employee = getEmployeeById(id);
      if (employee == null) return;
      final updated = employee.copyWith(
        isActive: true,
        dismissalDate: null,
        dismissalReason: null,
      );
      await _db.updateEmployee(updated);
      await loadEmployees();
    } catch (e) {
      _error = 'Ошибка восстановления: $e';
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
  // WORK SCHEDULES
  // ==========================================================================

  Future<void> loadWorkScheduleTypes() async {
    _workScheduleTypes = await _db.getWorkScheduleTypes();
    notifyListeners();
  }

  Future<void> loadEmployeeSchedule(int employeeId) async {
    final schedule = await _db.getEmployeeCurrentSchedule(employeeId);
    if (schedule != null) {
      _employeeSchedules[employeeId] = schedule;
    } else {
      _employeeSchedules.remove(employeeId);
    }
    notifyListeners();
  }

  Future<void> loadAllEmployeeSchedules() async {
    _employeeSchedules.clear();
    for (var employee in _employees) {
      if (employee.id != null) {
        await loadEmployeeSchedule(employee.id!);
      }
    }
    notifyListeners();
  }

  Future<void> assignEmployeeSchedule(
    int employeeId,
    int scheduleTypeId,
    DateTime startDate,
  ) async {
    try {
      final current = _employeeSchedules[employeeId];
      if (current != null) {
        await _db.closeEmployeeSchedule(
          current['id'] as int,
          startDate.subtract(const Duration(days: 1)),
        );
      }
      await _db.assignEmployeeSchedule(employeeId, scheduleTypeId, startDate);
      final employee = getEmployeeById(employeeId);
      if (employee != null && !employee.isShiftWorker) {
        final updated = employee.copyWith(isShiftWorker: true);
        await _db.updateEmployee(updated);
        await loadEmployees();
      }
      await loadEmployeeSchedule(employeeId);
    } catch (e) {
      _error = 'Ошибка назначения графика: $e';
      notifyListeners();
    }
  }

  Future<void> closeEmployeeSchedule(int employeeId) async {
    try {
      final current = _employeeSchedules[employeeId];
      if (current != null) {
        await _db.closeEmployeeSchedule(current['id'] as int, DateTime.now());
        final employee = getEmployeeById(employeeId);
        if (employee != null && employee.isShiftWorker) {
          final updated = employee.copyWith(isShiftWorker: false);
          await _db.updateEmployee(updated);
          await loadEmployees();
        }
        await loadEmployeeSchedule(employeeId);
      }
    } catch (e) {
      _error = 'Ошибка завершения графика: $e';
      notifyListeners();
    }
  }

  // ==========================================================================
  // SCHEDULE EXCEPTIONS
  // ==========================================================================

  Future<void> loadScheduleExceptions(int employeeId) async {
    final exceptions = await _db.getScheduleExceptionsForEmployee(employeeId);
    _scheduleExceptions[employeeId] = exceptions;
    notifyListeners();
  }

  Future<void> addScheduleException(
    int employeeId,
    DateTime date,
    String exceptionType, {
    String? note,
  }) async {
    try {
      await _db.addScheduleException(
        employeeId,
        date,
        exceptionType,
        note: note,
      );
      await loadScheduleExceptions(employeeId);
    } catch (e) {
      _error = 'Ошибка добавления исключения: $e';
      notifyListeners();
    }
  }

  Future<void> deleteScheduleException(int exceptionId, int employeeId) async {
    try {
      await _db.deleteScheduleException(exceptionId);
      await loadScheduleExceptions(employeeId);
    } catch (e) {
      _error = 'Ошибка удаления исключения: $e';
      notifyListeners();
    }
  }

  /// Получить статус сотрудника на конкретную дату
  Future<WorkStatus> getEmployeeStatusOnDate(
    int employeeId,
    DateTime date,
  ) async {
    return await _db.getEmployeeStatusOnDate(employeeId, date);
  }

  /// Проверить, является ли дата рабочим днём для сотрудника (учитывая график)
  Future<bool> isWorkingDay(int employeeId, DateTime date) async {
    final status = await _db.getEmployeeStatusOnDate(employeeId, date);
    return status == WorkStatus.regularWork ||
        status == WorkStatus.exceptionWork;
  }

  // ==========================================================================
  // WORK SITES
  // ==========================================================================

  Future<void> loadWorkSites() async {
    _workSites = await _db.getAllWorkSites();
    notifyListeners();
  }

  Future<void> addWorkSite(WorkSite site) async {
    try {
      await _db.insertWorkSite(site);
      await loadWorkSites();
    } catch (e) {
      _error = 'Ошибка добавления участка: $e';
      notifyListeners();
    }
  }

  Future<void> updateWorkSite(WorkSite site) async {
    try {
      await _db.updateWorkSite(site);
      await loadWorkSites();
    } catch (e) {
      _error = 'Ошибка обновления участка: $e';
      notifyListeners();
    }
  }

  Future<void> deleteWorkSite(int id) async {
    try {
      await _db.deleteWorkSite(id);
      await loadWorkSites();
    } catch (e) {
      _error = 'Ошибка удаления участка: $e';
      notifyListeners();
    }
  }

  // ==========================================================================
  // WORK TYPES
  // ==========================================================================

  Future<void> loadWorkTypes() async {
    _workTypes = await _db.getAllWorkTypes();
    notifyListeners();
  }

  Future<void> addWorkType(WorkType workType) async {
    try {
      await _db.insertWorkType(workType);
      await loadWorkTypes();
    } catch (e) {
      _error = 'Ошибка добавления вида работы: $e';
      notifyListeners();
    }
  }

  Future<void> updateWorkType(WorkType workType) async {
    try {
      await _db.updateWorkType(workType);
      await loadWorkTypes();
    } catch (e) {
      _error = 'Ошибка обновления вида работы: $e';
      notifyListeners();
    }
  }

  Future<void> deleteWorkType(int id) async {
    try {
      await _db.deleteWorkType(id);
      await loadWorkTypes();
    } catch (e) {
      _error = 'Ошибка удаления вида работы: $e';
      notifyListeners();
    }
  }

  // ==========================================================================
  // MACHINERY
  // ==========================================================================

  Future<void> loadMachinery() async {
    _machinery = await _db.getAllMachinery();
    notifyListeners();
  }

  Future<void> addMachinery(Machinery item) async {
    try {
      await _db.insertMachinery(item);
      await loadMachinery();
    } catch (e) {
      _error = 'Ошибка добавления техники: $e';
      notifyListeners();
    }
  }

  Future<void> updateMachinery(Machinery item) async {
    try {
      await _db.updateMachinery(item);
      await loadMachinery();
    } catch (e) {
      _error = 'Ошибка обновления техники: $e';
      notifyListeners();
    }
  }

  Future<void> deleteMachinery(int id) async {
    try {
      await _db.deleteMachinery(id);
      await loadMachinery();
    } catch (e) {
      _error = 'Ошибка удаления техники: $e';
      notifyListeners();
    }
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

  Future<List<TimesheetRecord>> getTimesheetForDate(DateTime date) async {
    return await _db.getTimesheetByPeriod(date, date);
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
            hoursWorked: record.hoursWorked,
            overtimeHours: record.overtimeHours,
            workTypeId: record.workTypeId,
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

  // ==========================================================================
  // PAYMENTS
  // ==========================================================================

  Future<void> loadPayments(
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
      await loadPayments(payment.employeeId);
    } catch (e) {
      _error = 'Ошибка добавления выплаты: $e';
      notifyListeners();
    }
  }

  Future<void> deletePayment(int id, int employeeId) async {
    try {
      await _db.deletePayment(id);
      await loadPayments(employeeId);
    } catch (e) {
      _error = 'Ошибка удаления выплаты: $e';
      notifyListeners();
    }
  }

  // ==========================================================================
  // VACATIONS
  // ==========================================================================

  Future<void> loadVacations(int employeeId) async {
    _vacations = await _db.getVacationsByEmployee(employeeId);
    notifyListeners();
  }

  Future<void> addVacation(Vacation vacation) async {
    try {
      await _db.insertVacation(vacation);
      await loadVacations(vacation.employeeId);
    } catch (e) {
      _error = 'Ошибка добавления отпуска: $e';
      notifyListeners();
    }
  }

  Future<void> deleteVacation(int id, int employeeId) async {
    try {
      await _db.deleteVacation(id);
      await loadVacations(employeeId);
    } catch (e) {
      _error = 'Ошибка удаления отпуска: $e';
      notifyListeners();
    }
  }

  // ==========================================================================
  // SICK LEAVES
  // ==========================================================================

  Future<void> loadSickLeaves(int employeeId) async {
    _sickLeaves = await _db.getSickLeavesByEmployee(employeeId);
    notifyListeners();
  }

  Future<void> addSickLeave(SickLeave sickLeave) async {
    try {
      await _db.insertSickLeave(sickLeave);
      await loadSickLeaves(sickLeave.employeeId);
    } catch (e) {
      _error = 'Ошибка добавления больничного: $e';
      notifyListeners();
    }
  }

  Future<void> deleteSickLeave(int id, int employeeId) async {
    try {
      await _db.deleteSickLeave(id);
      await loadSickLeaves(employeeId);
    } catch (e) {
      _error = 'Ошибка удаления больничного: $e';
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

  Future<List<Map<String, dynamic>>> getWorkReportBySites(
    DateTime start,
    DateTime end,
  ) async {
    return await _db.getWorkReportBySites(start, end);
  }

  Future<List<Map<String, dynamic>>> getMachineryReport(
    DateTime start,
    DateTime end,
  ) async {
    return await _db.getMachineryReport(start, end);
  }

  Future<void> updatePayment(Payment payment) async {
    try {
      await _db.updatePayment(payment);
      // Перезагружаем выплаты для этого сотрудника
      await loadPayments(payment.employeeId);
    } catch (e) {
      _error = 'Ошибка обновления выплаты: $e';
      notifyListeners();
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
