// lib/providers/app_provider.dart

import 'package:flutter/material.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import '../services/app_database.dart';
import '../services/local_backups.dart';
import '../services/platform.dart';

class AppProvider extends ChangeNotifier {
  AppProvider(this._appDb, {this._backupService, bool? operatorMode})
    : _operatorMode = operatorMode ?? isAndroidApp;

  /// Программа оператора (этап 4): записывается только табель, ставок,
  /// сумм, выплат и расчётов оператор не видит и не меняет. Сервер те же
  /// правила проверяет сам — здесь правка просто не начинается. С 6.9 —
  /// по роли вошедшего (на телефоне работают и бухгалтер, и админ); до
  /// входа — по устройству.
  bool get operatorMode => _operatorMode;
  bool _operatorMode;

  set operatorMode(bool value) {
    if (value == _operatorMode) return;
    _operatorMode = value;
    notifyListeners();
    // Полной программе нужны текущие ставки — оператору их не загружали.
    if (!value) loadEmployees();
  }

  /// Меняется при полном восстановлении из копии (база переоткрывается).
  AppDatabase _appDb;
  final LocalBackups? _backupService;

  /// Файловые копии базы; null — их нет (веб-версия).
  LocalBackups? get backups => _backupService;

  /// Файловые копии и восстановление из них есть на этой платформе.
  bool get hasLocalBackups => _backupService != null;

  LocalBackups get backupService =>
      _backupService ??
      (throw UnsupportedError('Резервных копий в этой версии программы нет'));

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
  SettingsRepository get _settingsRepo => _appDb.repos.settings;
  PayrollService get _payrollService => _appDb.repos.payrollService;

  // Списки данных
  List<Employee> _employees = [];
  List<TimesheetRecord> _timesheetRecords = [];
  List<Payment> _payments = [];
  List<EmployeeRate> _employeeRates = [];

  /// Ставки, действующие сегодня, по сотрудникам (null — ставки нет).
  Map<String, EmployeeRate?> _currentRates = {};
  PayrollMonthReport? _payrollReport;
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

  /// Ставка сотрудника, действующая сегодня (null — нет ставки на сегодня;
  /// оператор ставок не видит).
  EmployeeRate? currentRate(String employeeId) => _currentRates[employeeId];

  /// Последний загруженный отчёт ([loadPayrollReport]).
  PayrollMonthReport? get payrollReport => _payrollReport;
  List<PayrollResult> get payrollResults => _payrollReport?.results ?? const [];
  Map<String, double> get startingBalances =>
      _payrollReport?.startingBalances ?? const {};
  CompanySettings? get companySettings => _companySettings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Закрытые месяцы (ключи [PeriodGuard.monthKey]) — по последней
  /// синхронизации.
  Set<int> get lockedMonths => Set.unmodifiable(_lockedMonths);

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
    final message = _periodViolation(table, before, after);
    if (message == null) return true;
    _notice = message;
    notifyListeners();
    return false;
  }

  /// Почему правка задевает закрытый месяц (null — не задевает).
  String? _periodViolation(
    String table,
    Map<String, Object?>? before,
    Map<String, Object?>? after,
  ) {
    if (_lockedMonths.isEmpty) return null;
    final locked = PeriodGuard(_lockedMonths).violation(
      table,
      before,
      false,
      after ?? before ?? const {},
      after == null,
    );
    if (locked == null) return null;
    return '${PeriodLockedException(locked.$1, locked.$2).message}. '
        'Открыть месяц может администратор.';
  }

  /// Оператору доступен только табель: иначе — сообщение и false.
  bool _notOperator() {
    if (!operatorMode) return true;
    _notice =
        'Оператор вводит только табель — остальное меняют бухгалтер '
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
    if (!operatorMode) {
      final today = DateTime.now();
      _currentRates = {
        for (final e in _employees)
          if (e.id != null) e.id!: await _ratesRepo.at(e.id!, today),
      };
    }
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

  /// Добавить ставку (с любой даты: соседние периоды согласуются, см.
  /// [planAddRate]). Возвращает null, если записано, иначе — почему нет.
  Future<String?> addRate(EmployeeRate rate) =>
      _changeRates(rate.employeeId, (history) => planAddRate(history, rate));

  /// Изменить ставку: суммы, дату начала (между соседними ставками), дату
  /// окончания (только у последней). null — записано, иначе — почему нет.
  Future<String?> updateRate(EmployeeRate rate) =>
      _changeRates(rate.employeeId, (history) => planUpdateRate(history, rate));

  /// Удалить ставку: её период переходит к предыдущей ставке. null —
  /// записано, иначе — почему нет.
  Future<String?> deleteRate(EmployeeRate rate) => _changeRates(
    rate.employeeId,
    (history) => planDeleteRate(history, rate.id!),
  );

  Future<String?> _changeRates(
    String employeeId,
    List<RateChange> Function(List<EmployeeRate> history) plan,
  ) async {
    if (operatorMode) {
      return 'Ставки меняют бухгалтер или администратор.';
    }
    final List<RateChange> changes;
    try {
      changes = plan(await _ratesRepo.history(employeeId));
    } on RateTimelineException catch (e) {
      return e.message;
    }
    if (changes.isEmpty) return null;
    // Те же правила, что у сервера: ни одна правка не задевает закрытый
    // месяц (сдвиг границы — только открытыми днями).
    for (final c in changes) {
      final locked = _periodViolation(
        'employee_rates',
        _rateRow(c.before),
        _rateRow(c.after),
      );
      if (locked != null) {
        return '$locked Чтобы ставка поменялась с какой-то даты открытого '
            'месяца, добавьте новую ставку с этой даты.';
      }
    }
    try {
      await _ratesRepo.apply(changes);
      await _syncEmployeeRates(employeeId);
    } catch (e) {
      return 'Ошибка сохранения ставки: $e';
    }
    await loadEmployeeRates(employeeId: employeeId);
    await loadEmployees();
    setNeedRefreshReports(true);
    return null;
  }

  static Map<String, Object?>? _rateRow(EmployeeRate? r) => r == null
      ? null
      : {
          'employee_uuid': r.employeeId,
          'base_rate': r.baseRate,
          'field_rate': r.fieldRate,
          'start_date': formatDateIso(r.startDate),
          'end_date': formatDateIsoOrNull(r.endDate),
        };

  /// Ставки в карточке сотрудника — копия действующей сегодня (или
  /// последней) ставки из истории: их видят программы прежних версий.
  Future<void> _syncEmployeeRates(String employeeId) async {
    final employee = await _employeesRepo.byId(employeeId);
    if (employee == null) return;
    final history = await _ratesRepo.history(employeeId);
    final current = rateOn(history, DateTime.now()) ?? history.lastOrNull;
    if (current == null) return;
    if (current.baseRate != employee.baseRate ||
        current.fieldRate != employee.fieldRate) {
      await _employeesRepo.update(
        employee.copyWith(
          baseRate: current.baseRate,
          fieldRate: current.fieldRate,
        ),
      );
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

  /// Отметки дня из черновика (6.10) одной транзакцией: [marks] —
  /// сотрудник → новая запись (null — снять отметку). Закрытый месяц —
  /// объяснение в [takeNotice] и false.
  Future<bool> saveDayMarks(
    DateTime date,
    Map<String, TimesheetRecord?> marks,
  ) async {
    if (marks.isEmpty) return true;
    if (!_dayAllowed('timesheet', null, date)) return false;
    try {
      await _appDb.db.transaction(() async {
        for (final MapEntry(key: id, value: record) in marks.entries) {
          final existing = await _timesheetRepo.on(id, date);
          if (record == null) {
            if (existing?.id != null) {
              await _timesheetRepo.delete(existing!.id!);
            }
          } else if (existing == null) {
            await _timesheetRepo.add(record);
          } else {
            // Не copyWith: `workPlace: null` в нём значит «не менять».
            await _timesheetRepo.update(
              TimesheetRecord(
                id: existing.id,
                employeeId: existing.employeeId,
                date: existing.date,
                dayType: record.dayType,
                days: record.days,
                workPlace: record.workPlace,
                notes: existing.notes,
                createdAt: existing.createdAt,
              ),
            );
          }
        }
      });
    } catch (e) {
      _notice = 'Отметки не сохранены: $e';
      notifyListeners();
      return false;
    }
    if (_currentPeriodStart != null && _currentPeriodEnd != null) {
      await loadTimesheet(
        _currentPeriodStart!,
        _currentPeriodEnd!,
        employeeId: _currentTimesheetEmployee,
      );
    } else {
      notifyListeners();
    }
    setNeedRefreshReports(true);
    return true;
  }

  Future<void> saveTimesheetRecord(TimesheetRecord record) async {
    if (!_dayAllowed('timesheet', null, record.date)) return;
    try {
      final existing = await _timesheetRepo.on(record.employeeId, record.date);
      if (existing != null) {
        // Не copyWith: `workPlace: null` в нём значит «не менять», а у
        // больничного, отпуска и выходного места работы нет.
        final updated = TimesheetRecord(
          id: existing.id,
          employeeId: existing.employeeId,
          date: existing.date,
          dayType: record.dayType,
          days: record.days,
          workPlace: record.workPlace,
          notes: record.notes ?? existing.notes,
          createdAt: existing.createdAt,
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

  /// Пустые клетки нерабочих дней месяца по производственному календарю
  /// (6.6) — у сотрудников, работающих в этот день (принят, не уволен):
  /// (сотрудник, день). Заполненные клетки сюда не входят.
  Future<List<(Employee, DateTime)>> emptyDaysOff(int year, int month) async {
    final taken = {
      for (final r in await _timesheetRepo.inPeriod(
        DateTime(year, month, 1),
        DateTime(year, month + 1, 0),
      ))
        (r.employeeId, r.date.day),
    };
    return [
      for (final e in await _employeesRepo.all())
        if (e.id != null)
          for (final d in ProductionCalendar.daysOff(year, month))
            if (!taken.contains((e.id, d)) &&
                !calendarDay(e.hireDate).isAfter(DateTime(year, month, d)) &&
                e.isActiveOn(DateTime(year, month, d)))
              (e, DateTime(year, month, d)),
    ];
  }

  /// «Отметить выходные» (6.6): «В» во все пустые клетки нерабочих дней
  /// месяца ([emptyDaysOff]). Закрытый месяц — объяснение и 0. Возвращает,
  /// сколько клеток отмечено.
  Future<int> fillDaysOff(int year, int month) async {
    if (!_dayAllowed('timesheet', null, DateTime(year, month, 1))) return 0;
    var added = 0;
    try {
      for (final (e, day) in await emptyDaysOff(year, month)) {
        try {
          await _timesheetRepo.add(
            TimesheetRecord(
              employeeId: e.id!,
              date: day,
              dayType: 'dayoff',
              days: 1,
            ),
          );
          added++;
        } on DuplicateEntryException {
          // Клетку успели заполнить (например, пришло с сервера) — не трогаем.
        }
      }
    } catch (e) {
      _error = 'Ошибка отметки выходных: $e';
    }
    if (_currentPeriodStart != null && _currentPeriodEnd != null) {
      await loadTimesheet(
        _currentPeriodStart!,
        _currentPeriodEnd!,
        employeeId: _currentTimesheetEmployee,
      );
    } else {
      notifyListeners();
    }
    if (added > 0) setNeedRefreshReports(true);
    return added;
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

  /// Отчёт месяца ([PayrollService.monthReport]): открытый месяц — свежий
  /// пересчёт по данным этой базы (сразу видны и неотправленные правки),
  /// закрытый — расчёт, зафиксированный сервером, с отметкой расхождений.
  /// Приложение расчёты не сохраняет: сохранённые расчёты ведёт сервер,
  /// пересчитывая открытые месяцы после каждой принятой правки.
  Future<void> loadPayrollReport(int year, int month) async {
    _setLoading(true);
    try {
      _payrollReport = await _payrollService.monthReport(
        year,
        month,
        lockedMonths: _lockedMonths,
      );
      _error = null;
    } catch (e) {
      _error = 'Ошибка загрузки расчёта: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Отчёт за месяц без смены [payrollReport] (для окна закрытия месяца).
  Future<PayrollMonthReport> payrollReportFor(int year, int month) =>
      _payrollService.monthReport(year, month, lockedMonths: _lockedMonths);

  /// Месяцы `(год, месяц)`, где в этой базе есть табель или выплаты, по
  /// возрастанию.
  Future<List<(int, int)>> dataMonths() async {
    final keys = <int>{
      for (final r in await _timesheetRepo.inPeriod(
        DateTime(1900),
        DateTime(2200),
      ))
        PeriodGuard.monthKey(r.date.year, r.date.month),
      for (final p in await _paymentsRepo.list())
        PeriodGuard.monthKey(p.paymentDate.year, p.paymentDate.month),
    };
    return [for (final k in keys.toList()..sort()) (k ~/ 12, k % 12 + 1)];
  }

  /// Сводка главного экрана (6.8) на [today] (по умолчанию — сегодня).
  /// Общее состояние провайдера (отчёт, выплаты, табель экранов) не меняет.
  Future<DashboardSummary> dashboard({DateTime? today}) async {
    final day = calendarDay(today ?? DateTime.now());
    final previous = DateTime(day.year, day.month - 1, 1);
    final monthEnd = DateTime(day.year, day.month + 1, 0);
    return buildDashboard(
      today: day,
      employees: await _employeesRepo.all(),
      records: await _timesheetRepo.inPeriod(previous, monthEnd),
      current: await _payrollService.monthReport(
        day.year,
        day.month,
        lockedMonths: _lockedMonths,
      ),
      previous: isMonthLocked(previous.year, previous.month)
          ? null
          : await _payrollService.monthReport(
              previous.year,
              previous.month,
              lockedMonths: _lockedMonths,
            ),
      currentPayments: await _paymentsRepo.list(
        start: DateTime(day.year, day.month, 1),
        end: monthEnd,
      ),
      dataMonths: await dataMonths(),
      lockedMonths: _lockedMonths,
    );
  }

  /// Выплаты сотрудника за месяц без смены [payments] (окно расчёта из
  /// сводки).
  Future<List<Payment>> paymentsInMonth(
    String employeeId,
    int year,
    int month,
  ) => _paymentsRepo.list(
    employeeId: employeeId,
    start: DateTime(year, month, 1),
    end: DateTime(year, month + 1, 0),
  );

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
  Future<String> createSyncSafetyBackup() =>
      backupService.createSafetyBackup(_appDb.db, prefix: 'backup_before_sync');

  // ==========================================================================
  // РЕЗЕРВНОЕ КОПИРОВАНИЕ
  // ==========================================================================

  Future<String?> createBackup() async {
    final backups = _backupService;
    if (backups == null) return null;
    try {
      return await backups.createBackup(_appDb.db, type: BackupType.daily);
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
    final backups = _backupService;
    if (backups == null) return;
    try {
      await backups.createBackup(_appDb.db, type: BackupType.daily);
      await backups.createBackup(_appDb.db, type: BackupType.monthly);
    } catch (e) {
      // Автобэкап не должен нарушать работу приложения
      debugPrint('autoBackup error: $e');
    }
  }

  Future<List<BackupInfo>> getBackups() async {
    return await _backupService?.getBackups() ?? const [];
  }

  Future<void> deleteBackup(String path) async {
    try {
      await backupService.deleteBackup(path);
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
      return backupService.detectFormat(backupPath);
    } on RestoreException {
      return null;
    }
  }

  /// Таблицы копии, которые можно восстановить по отдельности
  /// (только копии нового формата).
  List<String> restorableTables(String backupPath) =>
      backupService.restorableTables(backupPath);

  /// Заменяет всю базу копией (любого формата; старая переносится
  /// конвертером). Перед этим — копия текущей базы. При ошибке текущая
  /// база остаётся, причина — в [error].
  Future<bool> restoreFullBackup(String backupPath) async {
    if (!_notOperator()) return false;
    try {
      final backups = backupService;
      await backups.createSafetyBackup(_appDb.db);
      await backups.restoreFull(
        _appDb,
        backupPath,
        beforeReplace: () async => beforeDatabaseReplaced?.call(),
        onReopened: (reopened) {
          _appDb = reopened;
          _databaseGeneration++;
        },
      );
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
    final backups = backupService;
    await backups.createSafetyBackup(_appDb.db);
    var count = 0;
    for (final table in businessTables.where(tables.contains)) {
      count += await backups.restoreTable(_appDb.db, backupPath, table);
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
    final backups = backupService;
    await backups.createSafetyBackup(_appDb.db);
    final count = await backups.restoreRows(
      _appDb.db,
      backupPath,
      table,
      uuids,
    );
    await loadAllData();
    setNeedRefreshReports(true);
    return count;
  }

  /// Закрыть базу: перед установкой обновления (6.5) — чтобы все записи
  /// были на диске до закрытия программы; в тестах. После — только выход.
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
