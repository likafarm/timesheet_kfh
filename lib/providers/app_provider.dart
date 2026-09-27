// lib/providers/app_provider.dart

import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import '../services/app_database.dart';
import '../services/backup_service.dart';
import '../services/platform.dart';

class AppProvider extends ChangeNotifier {
  AppProvider(
    this._appDb, {
    BackupService? backupService,
    bool? operatorMode,
  }) : _backupService = backupService ?? BackupService(),
       operatorMode = operatorMode ?? isAndroidApp;

  /// Программа оператора (телефон, этап 4): записывается только табель,
  /// ставок, сумм, выплат и расчётов оператор не видит и не меняет. Сервер
  /// те же правила проверяет сам — здесь правка просто не начинается.
  final bool operatorMode;

  /// Меняется при полном восстановлении из копии (база переоткрывается).
  AppDatabase _appDb;
  final BackupService _backupService;

  BackupService get backupService => _backupService;

  /// Перед заменой файла базы (полное восстановление): остановить то, что
  /// с ней работает в фоне (синхронизацию).
  Future<void> Function()? beforeDatabaseReplaced;

  /// Путь к файлу базы (для «О программе»).
  String get databasePath => _appDb.path;

  /// Открытая локальная база (для синхронизации). После полного
  /// восстановления это другой объект — см. [databaseGeneration].
  LocalDatabase get localDatabase => _appDb.db;

  /// Растёт, когда база переоткрыта (полное восстановление из копии).
  int get databaseGeneration => _databaseGeneration;
  int _databaseGeneration = 0;

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

  /// Закрытые на сервере месяцы ([PeriodGuard.monthKey]).
  Set<int> _lockedMonths = {};

  /// Сообщение для строки внизу окна (например, «месяц закрыт»).
  String? _notice;

  // Для перезагрузки табеля
  DateTime? _currentPeriodStart;
  DateTime? _currentPeriodEnd;
  String? _currentTimesheetEmployee;

  /// Последняя загрузка выплат — повторяется после синхронизации.
  Future<void> Function()? _reloadPayments;

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

  /// Месяц закрыт на сервере — правки в нём не записываются.
  bool isMonthLocked(int year, int month) =>
      _lockedMonths.contains(PeriodGuard.monthKey(year, month));

  /// Есть сообщение для пользователя — забрать его (показывается один раз).
  String? takeNotice() {
    final n = _notice;
    _notice = null;
    return n;
  }

  /// Проверка по правилам сервера ([PeriodGuard]): правка не задевает
  /// закрытый месяц. Иначе — сообщение в [takeNotice] и false.
  /// [after] = null — удаление.
  bool _allowedInOpenPeriod(
    String table,
    Map<String, Object?>? before,
    Map<String, Object?>? after,
  ) {
    if (_lockedMonths.isEmpty) return true;
    final locked = PeriodGuard(_lockedMonths).violation(
      table,
      before,
      false,
      after ?? before ?? const {},
      after == null,
    );
    if (locked == null) return true;
    _notice =
        '${PeriodLockedException(locked.$1, locked.$2).message}. '
        'Открыть месяц может бухгалтер или администратор.';
    notifyListeners();
    return false;
  }

  /// Оператору доступен только табель: иначе — сообщение и false.
  bool _notOperator() {
    if (!operatorMode) return true;
    _notice = 'Оператор вводит только табель — остальное меняют бухгалтер '
        'или администратор.';
    notifyListeners();
    return false;
  }

  bool _dayAllowed(String table, DateTime? before, DateTime? after) {
    final column = table == 'payments' ? 'payment_date' : 'date';
    return _allowedInOpenPeriod(
      table,
      before == null ? null : {column: formatDateIso(before)},
      after == null ? null : {column: formatDateIso(after)},
    );
  }

  bool _monthAllowed(int year, int month) => _allowedInOpenPeriod(
    'payroll_results',
    null,
    {'year': year, 'month': month},
  );

  bool _rateAllowed(DateTime start) => _allowedInOpenPeriod(
    'employee_rates',
    null,
    {'start_date': formatDateIso(start), 'end_date': null},
  );

  /// Перечитать список закрытых месяцев (после синхронизации).
  Future<void> loadLockedMonths() async {
    _lockedMonths = await LocalSyncStore(_appDb.db).lockedMonths();
    notifyListeners();
  }

  // ==========================================================================
  // ЗАГРУЗКА ДАННЫХ
  // ==========================================================================

  Future<void> loadAllData() async {
    _setLoading(true);
    try {
      await Future.wait([
        loadEmployees(),
        loadCompanySettings(),
        loadLockedMonths(),
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
    _companySettings = await _settingsRepo.get();
    notifyListeners();
  }

  Future<void> updateCompanySettings(CompanySettings settings) async {
    if (!_notOperator()) return;
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
    if (!_notOperator()) return;
    if (!_rateAllowed(rateStartDate ?? employee.hireDate)) return;
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
    if (!_notOperator()) return;
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
    if (!_notOperator()) return;
    if (!_rateAllowed(rate.startDate)) return;
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
      _currentTimesheetEmployee = employeeId;
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
    if (!_dayAllowed('timesheet', null, date)) return;
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
    if (!_dayAllowed('timesheet', null, record.date)) return;
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
    if (!_dayAllowed('timesheet', null, record.date)) return;
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
    final old = _timesheetRecords.where((r) => r.id == record.id).firstOrNull;
    if (!_dayAllowed('timesheet', old?.date, record.date)) return;
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
    final old = _timesheetRecords.where((r) => r.id == id).firstOrNull;
    if (old != null && !_dayAllowed('timesheet', old.date, null)) return;
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
    _reloadPayments = () =>
        loadAllPayments(startDate: startDate, endDate: endDate);
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
    _reloadPayments = () => loadPaymentsByEmployee(
      employeeId,
      startDate: startDate,
      endDate: endDate,
    );
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
    if (!_notOperator()) return;
    if (!_dayAllowed('payments', null, payment.paymentDate)) return;
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
    if (!_notOperator()) return;
    final old = _payments.where((p) => p.id == payment.id).firstOrNull;
    if (!_dayAllowed('payments', old?.paymentDate, payment.paymentDate)) {
      return;
    }
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
    if (!_notOperator()) return;
    final old = _payments.where((p) => p.id == id).firstOrNull;
    if (old != null && !_dayAllowed('payments', old.paymentDate, null)) return;
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

  /// Расчёты месяца для отчёта — без сотрудников, у которых в месяце нет ни
  /// начислений, ни выплат.
  Future<void> loadPayrollResultsForMonth(int year, int month) async {
    _setLoading(true);
    try {
      _payrollResults = await _payrollService.resultsForReport(year, month);
      _error = null;
    } catch (e) {
      _error = 'Ошибка загрузки результатов расчёта: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> calculatePayrollForMonth(int year, int month) async {
    if (!_notOperator()) return;
    if (!_monthAllowed(year, month)) return;
    _setLoading(true);
    try {
      // Сотрудники без начислений и выплат за месяц в расчёт не входят.
      await _payrollService.saveMonth(year, month);
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
    if (!_notOperator()) return;
    if (!_monthAllowed(year, month)) return;
    // Если начислений и выплат не осталось — прежний расчёт удаляется.
    await _payrollService.saveMonth(year, month, employeeId: employeeId);
    setNeedRefreshReports(true);
  }

  // ==========================================================================
  // СИНХРОНИЗАЦИЯ
  // ==========================================================================

  /// Синхронизация записала в базу изменения с сервера: перечитать то, что
  /// показывают экраны (те же периоды и фильтры).
  Future<void> reloadAfterSync() async {
    await loadAllData();
    final start = _currentPeriodStart, end = _currentPeriodEnd;
    if (start != null && end != null) {
      await loadTimesheet(start, end, employeeId: _currentTimesheetEmployee);
    }
    await _reloadPayments?.call();
    setNeedRefreshReports(true);
  }

  /// Копия базы перед первым входом на сервер
  /// (`backup_before_sync_<дата-время>.db`). Бросает исключение, если копию
  /// сделать не удалось.
  Future<String> createSyncSafetyBackup() => _backupService.createSafetyBackup(
    _appDb.db,
    prefix: 'backup_before_sync',
  );

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
  // ВОССТАНОВЛЕНИЕ ИЗ КОПИЙ
  // ==========================================================================

  /// Формат копии; null — файл не копия базы программы.
  BackupFormat? backupFormat(String backupPath) {
    try {
      return detectBackupFormat(backupPath);
    } on RestoreException {
      return null;
    }
  }

  /// Таблицы копии, которые можно восстановить по отдельности
  /// (только копии нового формата).
  List<String> restorableTables(String backupPath) =>
      BackupRestorer.restorableTables(backupPath);

  /// Заменяет всю базу копией (любого формата; старая переносится
  /// конвертером). Перед этим — копия текущей базы. При ошибке текущая
  /// база остаётся, причина — в [error].
  Future<bool> restoreFullBackup(String backupPath) async {
    if (!_notOperator()) return false;
    try {
      await _backupService.createSafetyBackup(_appDb.db);
      final deviceId = await _appDb.db.deviceId();
      final path = _appDb.path;
      final prepared = '$path.restore';
      await Isolate.run(
        () => prepareFullRestore(
          backupPath: backupPath,
          targetPath: prepared,
          deviceId: deviceId,
        ),
      );
      await beforeDatabaseReplaced?.call();
      await _appDb.close();
      try {
        replaceDatabaseFile(prepared, path);
      } finally {
        _appDb = await AppDatabase.openFile(path);
        _databaseGeneration++;
      }
      await loadAllData();
      setNeedRefreshReports(true);
      return true;
    } catch (e) {
      _error = 'Ошибка восстановления: $e';
      notifyListeners();
      return false;
    }
  }

  /// Таблицы целиком как в копии (только копии нового формата).
  /// Возвращает число восстановленных строк.
  Future<int> restoreTables(String backupPath, List<String> tables) async {
    if (!_notOperator()) return 0;
    await _backupService.createSafetyBackup(_appDb.db);
    final restorer = BackupRestorer(_appDb.db);
    var count = 0;
    for (final table in businessTables.where(tables.contains)) {
      count += await restorer.restoreTable(backupPath, table);
    }
    await loadAllData();
    setNeedRefreshReports(true);
    return count;
  }

  /// Отдельные строки таблицы из копии нового формата.
  Future<int> restoreSelectedRows(
    String backupPath,
    String table,
    List<String> uuids,
  ) async {
    if (!_notOperator()) return 0;
    await _backupService.createSafetyBackup(_appDb.db);
    final count = await BackupRestorer(
      _appDb.db,
    ).restoreRows(backupPath, table, uuids);
    await loadAllData();
    setNeedRefreshReports(true);
    return count;
  }

  /// Закрыть базу (тесты; программа закрывает её вместе с процессом).
  @visibleForTesting
  Future<void> closeDatabase() => _appDb.close();

  // ==========================================================================
  // ПРОСМОТР И ПРАВКА БАЗЫ
  // ==========================================================================

  RawTables get _raw => RawTables(_appDb.db);

  Future<List<String>> getTableNames() => _raw.tableNames();

  Future<List<ColumnInfo>> getTableColumns(String table) => _raw.columns(table);

  Future<List<Map<String, Object?>>> getTableData(
    String table, {
    int limit = 100,
  }) => _raw.rows(table, limit: limit);

  bool isTableEditable(String table) => _raw.isEditable(table);

  Future<void> updateTableRow(
    String table,
    String uuid,
    Map<String, Object?> values,
  ) async {
    if (!_notOperator()) return;
    await _raw.updateRow(table, uuid, values);
    await loadAllData();
    setNeedRefreshReports(true);
  }

  Future<void> setTableRowDeleted(
    String table,
    String uuid,
    bool deleted,
  ) async {
    if (!_notOperator()) return;
    await _raw.setDeleted(table, uuid, deleted);
    await loadAllData();
    setNeedRefreshReports(true);
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
