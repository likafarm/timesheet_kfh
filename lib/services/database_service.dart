// lib/services/database_service.dart

import 'dart:async';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_domain/kfh_domain.dart' as payroll;
import 'db_location.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;
  String? _databasePath;

  /// Путь к открытой базе (null — база ещё не открыта).
  String? get databasePath => _databasePath;

  /// Открытие базы идёт один раз: параллельные запросы при старте
  /// (например, `Future.wait` в `AppProvider`) ждут один и тот же Future,
  /// иначе они одновременно запускают перенос базы и мешают друг другу.
  Future<Database>? _opening;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _opening ??= _initDatabase();
    try {
      _database = await _opening!;
    } finally {
      _opening = null;
    }
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final location = await resolveDatabasePath(
      dataDir: appDataDirectory(),
      legacyDirs: legacyDatabaseDirectories(),
    );
    if (location.migratedFrom != null) {
      await logDbLocation(
        'База перенесена: ${location.migratedFrom} -> ${location.path}',
      );
    }
    if (location.error != null) await logDbLocation(location.error!);
    final path = location.path;
    _databasePath = path;
    return await openDatabase(
      path,
      version: 8,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // --- company_settings ---
    await db.execute('''
      CREATE TABLE company_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        company_name TEXT NOT NULL DEFAULT 'КФХ',
        director_name TEXT,
        inn TEXT,
        ogrn TEXT,
        bank_account TEXT,
        bank_name TEXT,
        legal_address TEXT,
        phone TEXT,
        default_work_day_hours REAL NOT NULL DEFAULT 8.0,
        overtime_multiplier REAL NOT NULL DEFAULT 1.5,
        night_shift_multiplier REAL NOT NULL DEFAULT 1.2
      )
    ''');
    await db.insert('company_settings', {
      'id': 1,
      'company_name': 'КФХ',
      'default_work_day_hours': 8.0,
      'overtime_multiplier': 1.5,
      'night_shift_multiplier': 1.2,
    });

    // --- employees ---
    await db.execute('''
      CREATE TABLE employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        position TEXT NOT NULL,
        hire_date TEXT NOT NULL,
        dismissal_date TEXT,
        base_rate REAL NOT NULL DEFAULT 0,
        field_rate REAL NOT NULL DEFAULT 0
      )
    ''');

    // --- employee_rates ---
    await db.execute('''
      CREATE TABLE employee_rates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        base_rate REAL NOT NULL,
        field_rate REAL NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
      )
    ''');

    // --- timesheet ---
    await db.execute('''
      CREATE TABLE timesheet (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        day_type TEXT NOT NULL DEFAULT 'work',
        days REAL NOT NULL DEFAULT 0,
        work_place TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
      )
    ''');

    // --- payments ---
    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        payment_date TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_type TEXT NOT NULL DEFAULT 'salary',
        period_start TEXT,
        period_end TEXT,
        payment_method TEXT,
        document_number TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
      )
    ''');

    // --- sick_leave ---
    await db.execute('''
      CREATE TABLE sick_leave (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        document_number TEXT,
        days_count INTEGER NOT NULL,
        paid_by_employer REAL,
        paid_by_fss REAL,
        notes TEXT,
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
      )
    ''');

    // --- vacation ---
    await db.execute('''
      CREATE TABLE vacation (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        vacation_type TEXT NOT NULL DEFAULT 'annual',
        days_count INTEGER NOT NULL,
        is_approved INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
      )
    ''');

    // --- payroll_results (НОВАЯ ТАБЛИЦА) ---
    await db.execute('''
      CREATE TABLE payroll_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        base_days REAL NOT NULL DEFAULT 0,
        field_days REAL NOT NULL DEFAULT 0,
        sick_days REAL NOT NULL DEFAULT 0,
        vacation_days REAL NOT NULL DEFAULT 0,
        total_salary REAL NOT NULL DEFAULT 0,
        base_rate_used REAL,
        field_rate_used REAL,
        calculated_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'calculated',
        skipped_work_days INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX idx_payroll_unique ON payroll_results(employee_id, year, month)',
    );

    // --- Индексы для существующих таблиц ---
    await db.execute(
      'CREATE INDEX idx_timesheet_employee_date ON timesheet(employee_id, date)',
    );
    await db.execute('CREATE INDEX idx_timesheet_date ON timesheet(date)');
    await db.execute(
      'CREATE INDEX idx_payments_employee_date ON payments(employee_id, payment_date)',
    );
    await db.execute(
      'CREATE INDEX idx_employee_rates_employee ON employee_rates(employee_id)',
    );
    await db.execute(
      'CREATE INDEX idx_employee_rates_active ON employee_rates(employee_id, start_date, end_date)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_timesheet_unique ON timesheet(employee_id, date)',
    );
  }

  // ==========================================================================
  // МИГРАЦИЯ: версия 6 -> 7 (добавление payroll_results)
  // ==========================================================================

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 6) {
      // Миграция 5->6 (уникальный индекс табеля)
      try {
        await db.execute(
          'CREATE UNIQUE INDEX idx_timesheet_unique ON timesheet(employee_id, date)',
        );
      } catch (_) {}
      await db.rawDelete('''
        DELETE FROM timesheet
        WHERE id NOT IN (
          SELECT MAX(id)
          FROM timesheet
          GROUP BY employee_id, date
        )
      ''');
    }
    if (oldVersion < 7) {
      // Создаём таблицу payroll_results
      await db.execute('''
        CREATE TABLE payroll_results (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          employee_id INTEGER NOT NULL,
          year INTEGER NOT NULL,
          month INTEGER NOT NULL,
          base_days REAL NOT NULL DEFAULT 0,
          field_days REAL NOT NULL DEFAULT 0,
          sick_days REAL NOT NULL DEFAULT 0,
          vacation_days REAL NOT NULL DEFAULT 0,
          total_salary REAL NOT NULL DEFAULT 0,
          base_rate_used REAL,
          field_rate_used REAL,
          calculated_at TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'calculated',
          FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
        )
      ''');
      await db.execute(
        'CREATE UNIQUE INDEX idx_payroll_unique ON payroll_results(employee_id, year, month)',
      );
    }
    if (oldVersion < 8) {
      await _normalizeCalendarDates(db);
      await db.execute('DROP INDEX IF EXISTS idx_timesheet_unique');
      await db.rawDelete('''
        DELETE FROM timesheet
        WHERE id NOT IN (
          SELECT MAX(id) FROM timesheet GROUP BY employee_id, date
        )
      ''');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_timesheet_unique ON timesheet(employee_id, date)',
      );
      try {
        await db.execute(
          'ALTER TABLE payroll_results ADD COLUMN skipped_work_days INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {
        // колонка уже есть
      }
    }
  }

  Future<void> _normalizeCalendarDates(Database db) async {
    const updates = [
      "UPDATE timesheet SET date = substr(date, 1, 10) WHERE date IS NOT NULL AND length(date) > 10",
      "UPDATE employees SET hire_date = substr(hire_date, 1, 10) WHERE hire_date IS NOT NULL AND length(hire_date) > 10",
      "UPDATE employees SET dismissal_date = substr(dismissal_date, 1, 10) WHERE dismissal_date IS NOT NULL AND length(dismissal_date) > 10",
      "UPDATE payments SET payment_date = substr(payment_date, 1, 10) WHERE payment_date IS NOT NULL AND length(payment_date) > 10",
      "UPDATE payments SET period_start = substr(period_start, 1, 10) WHERE period_start IS NOT NULL AND length(period_start) > 10",
      "UPDATE payments SET period_end = substr(period_end, 1, 10) WHERE period_end IS NOT NULL AND length(period_end) > 10",
      "UPDATE employee_rates SET start_date = substr(start_date, 1, 10) WHERE start_date IS NOT NULL AND length(start_date) > 10",
      "UPDATE employee_rates SET end_date = substr(end_date, 1, 10) WHERE end_date IS NOT NULL AND length(end_date) > 10",
    ];
    for (final sql in updates) {
      try {
        await db.execute(sql);
      } on DatabaseException {
        // таблица может отсутствовать на очень старых копиях
      }
    }
  }

  // ==========================================================================
  // EMPLOYEES (без изменений)
  // ==========================================================================

  Future<String> insertEmployee(Employee employee) async {
    final db = await database;
    final map = employee.toMap();
    map.remove('id');
    _toLegacyIds(map);
    return (await db.insert('employees', map)).toString();
  }

  Future<List<Employee>> getAllEmployees({bool activeOnly = false}) async {
    final db = await database;
    String where = '';
    List<dynamic> whereArgs = [];
    if (activeOnly) {
      where = 'WHERE dismissal_date IS NULL OR dismissal_date > ?';
      whereArgs = [formatDateIso(DateTime.now())];
    }
    final maps = await db.rawQuery(
      'SELECT * FROM employees $where ORDER BY full_name',
      whereArgs,
    );
    return maps.map((m) => Employee.fromMap(m)).toList();
  }

  Future<Employee?> getEmployeeById(String id) async {
    final db = await database;
    final maps = await db.query(
      'employees',
      where: 'id = ?',
      whereArgs: [int.parse(id)],
    );
    if (maps.isEmpty) return null;
    return Employee.fromMap(maps.first);
  }

  Future<int> updateEmployee(Employee employee) async {
    final db = await database;
    final map = employee.toMap();
    map.remove('id');
    _toLegacyIds(map);
    return await db.update(
      'employees',
      map,
      where: 'id = ?',
      whereArgs: [int.parse(employee.id!)],
    );
  }

  Future<int> deleteEmployee(String id) async {
    final db = await database;
    return await db.delete(
      'employees',
      where: 'id = ?',
      whereArgs: [int.parse(id)],
    );
  }

  // ==========================================================================
  // EMPLOYEE RATES (без изменений)
  // ==========================================================================

  Future<int> _insertEmployeeRate(EmployeeRate rate) async {
    final db = await database;
    final map = rate.toMap();
    map.remove('id');
    _toLegacyIds(map);
    return await db.insert('employee_rates', map);
  }

  Future<int> insertEmployeeRate(EmployeeRate rate) async {
    final db = await database;
    final current = await db.query(
      'employee_rates',
      where: 'employee_id = ? AND end_date IS NULL',
      whereArgs: [int.parse(rate.employeeId)],
    );
    if (current.isNotEmpty) {
      await db.update(
        'employee_rates',
        {
          'end_date': formatDateIso(
            rate.startDate.subtract(const Duration(days: 1)),
          ),
        },
        where: 'id = ?',
        whereArgs: [current.first['id']],
      );
    }
    return await _insertEmployeeRate(rate);
  }

  Future<List<EmployeeRate>> getEmployeeRateHistory(String employeeId) async {
    final db = await database;
    final maps = await db.query(
      'employee_rates',
      where: 'employee_id = ?',
      whereArgs: [int.parse(employeeId)],
      orderBy: 'start_date ASC',
    );
    return maps.map((m) => EmployeeRate.fromMap(m)).toList();
  }

  Future<EmployeeRate?> getEmployeeRateAtDate(
    String employeeId,
    DateTime date,
  ) async {
    final db = await database;
    final dateStr = formatDateIso(date);
    final maps = await db.query(
      'employee_rates',
      where:
          'employee_id = ? AND start_date <= ? AND (end_date IS NULL OR end_date >= ?)',
      whereArgs: [int.parse(employeeId), dateStr, dateStr],
      orderBy: 'start_date DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return EmployeeRate.fromMap(maps.first);
  }

  // ==========================================================================
  // TIMESHEET (без изменений)
  // ==========================================================================

  Future<int> insertTimesheetRecord(TimesheetRecord record) async {
    final db = await database;
    final map = record.toMap();
    map.remove('id');
    _toLegacyIds(map);
    map['created_at'] = DateTime.now().toIso8601String();
    try {
      return await db.insert(
        'timesheet',
        map,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('Запись на эту дату уже есть');
      }
      rethrow;
    }
  }

  Future<List<TimesheetRecord>> getTimesheetByPeriod(
    DateTime start,
    DateTime end, {
    String? employeeId,
  }) async {
    final db = await database;
    final range = dateRangeExclusiveEnd(start, end);
    String where = 'date >= ? AND date < ?';
    List<dynamic> whereArgs = [range.$1, range.$2];
    if (employeeId != null) {
      where += ' AND employee_id = ?';
      whereArgs.add(int.parse(employeeId));
    }
    final maps = await db.query(
      'timesheet',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'date DESC, employee_id',
    );
    return maps.map((m) => TimesheetRecord.fromMap(m)).toList();
  }

  Future<TimesheetRecord?> getTimesheetRecord(
    String employeeId,
    DateTime date,
  ) async {
    final db = await database;
    final dateStr = formatDateIso(date);
    final maps = await db.query(
      'timesheet',
      where: "employee_id = ? AND substr(date, 1, 10) = ?",
      whereArgs: [int.parse(employeeId), dateStr],
    );
    if (maps.isEmpty) return null;
    return TimesheetRecord.fromMap(maps.first);
  }

  Future<int> updateTimesheetRecord(TimesheetRecord record) async {
    final db = await database;
    final map = record.toMap();
    map.remove('id');
    _toLegacyIds(map);
    return await db.update(
      'timesheet',
      map,
      where: 'id = ?',
      whereArgs: [int.parse(record.id!)],
    );
  }

  Future<int> deleteTimesheetRecord(String id) async {
    final db = await database;
    return await db.delete(
      'timesheet',
      where: 'id = ?',
      whereArgs: [int.parse(id)],
    );
  }

  // ==========================================================================
  // PAYMENTS (без изменений)
  // ==========================================================================

  Future<int> insertPayment(Payment payment) async {
    final db = await database;
    final map = payment.toMap();
    map.remove('id');
    _toLegacyIds(map);
    map['created_at'] = DateTime.now().toIso8601String();
    return await db.insert('payments', map);
  }

  Future<List<Payment>> getPaymentsByEmployee(
    String employeeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    String where = 'employee_id = ?';
    List<dynamic> whereArgs = [int.parse(employeeId)];
    if (startDate != null && endDate != null) {
      final range = dateRangeExclusiveEnd(startDate, endDate);
      where += ' AND payment_date >= ? AND payment_date < ?';
      whereArgs.add(range.$1);
      whereArgs.add(range.$2);
    }
    final maps = await db.query(
      'payments',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'payment_date DESC',
    );
    return maps.map((m) => Payment.fromMap(m)).toList();
  }

  Future<List<Payment>> getAllPayments({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    String where = '1=1';
    List<dynamic> whereArgs = [];
    if (startDate != null && endDate != null) {
      final range = dateRangeExclusiveEnd(startDate, endDate);
      where += ' AND payment_date >= ? AND payment_date < ?';
      whereArgs.add(range.$1);
      whereArgs.add(range.$2);
    }
    final maps = await db.query(
      'payments',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'payment_date DESC',
    );
    return maps.map((m) => Payment.fromMap(m)).toList();
  }

  Future<int> updatePayment(Payment payment) async {
    final db = await database;
    final map = payment.toMap();
    map.remove('id');
    _toLegacyIds(map);
    return await db.update(
      'payments',
      map,
      where: 'id = ?',
      whereArgs: [int.parse(payment.id!)],
    );
  }

  Future<int> deletePayment(String id) async {
    final db = await database;
    return await db.delete(
      'payments',
      where: 'id = ?',
      whereArgs: [int.parse(id)],
    );
  }

  // ==========================================================================
  // COMPANY SETTINGS (без изменений)
  // ==========================================================================

  Future<Map<String, dynamic>?> getCompanySettings() async {
    final db = await database;
    final maps = await db.query('company_settings', where: 'id = 1');
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<int> updateCompanySettings(Map<String, dynamic> settings) async {
    final db = await database;
    settings.remove('id');
    return await db.update(
      'company_settings',
      settings,
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  // ==========================================================================
  // ДОПОЛНИТЕЛЬНЫЕ МЕТОДЫ ДЛЯ ПРОСМОТРА БАЗЫ
  // ==========================================================================

  Future<List<String>> getTableNames() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
    );
    return result.map((row) => row['name'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> getTableData(
    String tableName, {
    int limit = 100,
  }) async {
    final db = await database;
    if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(tableName)) {
      throw Exception('Недопустимое имя таблицы');
    }
    final result = await db.rawQuery('SELECT * FROM $tableName LIMIT $limit');
    return result;
  }

  Future<void> updateRow(
    String tableName,
    int id,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(tableName)) {
      throw Exception('Недопустимое имя таблицы');
    }
    data.remove('id');
    final sets = <String>[];
    final values = <dynamic>[];
    for (var entry in data.entries) {
      sets.add('${entry.key} = ?');
      values.add(entry.value);
    }
    if (sets.isEmpty) throw Exception('Нет данных для обновления');
    values.add(id);
    await db.rawUpdate(
      'UPDATE $tableName SET ${sets.join(', ')} WHERE id = ?',
      values,
    );
  }

  Future<void> deleteRow(String tableName, int id) async {
    final db = await database;
    if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(tableName)) {
      throw Exception('Недопустимое имя таблицы');
    }
    await db.rawDelete('DELETE FROM $tableName WHERE id = ?', [id]);
  }

  // ==========================================================================
  // PAYROLL RESULTS (НОВЫЕ МЕТОДЫ)
  // ==========================================================================

  /// Детальный расчёт зарплаты за месяц с учётом ставок на каждый день
  Future<Map<String, dynamic>> calculateMonthlySalaryDetailed(
    String employeeId,
    int year,
    int month,
  ) async {
    final employee = await getEmployeeById(employeeId);
    if (employee == null) throw Exception('Сотрудник не найден');

    final records = await getTimesheetByPeriod(
      DateTime(year, month, 1),
      DateTime(year, month + 1, 0),
      employeeId: employeeId,
    );
    final rates = await getEmployeeRateHistory(employeeId);

    return payroll
        .calculateMonthlySalary(
          employeeId: employeeId,
          year: year,
          month: month,
          records: records,
          rates: rates,
        )
        .toMap();
  }

  /// Сохраняет или обновляет результат расчёта
  Future<int> savePayrollResult(PayrollResult result) async {
    final db = await database;
    final map = result.toMap();
    map.remove('id');
    _toLegacyIds(map);

    final existing = await db.query(
      'payroll_results',
      where: 'employee_id = ? AND year = ? AND month = ?',
      whereArgs: [int.parse(result.employeeId), result.year, result.month],
    );
    if (existing.isNotEmpty) {
      await db.update(
        'payroll_results',
        map,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      return existing.first['id'] as int;
    } else {
      return await db.insert('payroll_results', map);
    }
  }

  /// Получение сохранённого результата для сотрудника за месяц
  Future<PayrollResult?> getPayrollResult(
    String employeeId,
    int year,
    int month,
  ) async {
    final db = await database;
    final maps = await db.query(
      'payroll_results',
      where: 'employee_id = ? AND year = ? AND month = ?',
      whereArgs: [int.parse(employeeId), year, month],
    );
    if (maps.isEmpty) return null;
    return PayrollResult.fromMap(maps.first);
  }

  /// Получение всех результатов за месяц (для сводки)
  Future<List<PayrollResult>> getPayrollResultsForMonth(
    int year,
    int month,
  ) async {
    final db = await database;
    final maps = await db.query(
      'payroll_results',
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
      orderBy: 'employee_id',
    );
    return maps.map((m) => PayrollResult.fromMap(m)).toList();
  }

  /// Возвращает дату последнего изменения табеля для сотрудника за месяц (максимальный created_at)
  Future<DateTime?> getLastTimesheetChange(
    String employeeId,
    int year,
    int month,
  ) async {
    final db = await database;
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    final range = dateRangeExclusiveEnd(start, end);
    final maps = await db.query(
      'timesheet',
      where: 'employee_id = ? AND date >= ? AND date < ?',
      whereArgs: [int.parse(employeeId), range.$1, range.$2],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DateTime.parse(maps.first['created_at'] as String);
  }

  // ==========================================================================
  // РАСЧЁТ ЗАРПЛАТЫ (старый, оставлен для совместимости, но не рекомендуется)
  // ==========================================================================

  Future<Map<String, dynamic>> calculateMonthlySalary(
    String employeeId,
    int year,
    int month,
  ) async {
    // Можно удалить или оставить для обратной совместимости
    return await calculateMonthlySalaryDetailed(employeeId, year, month);
  }

  /// Получает начальные балансы для всех сотрудников на начало указанной даты.
  /// (Сумма начислений за все месяцы ДО месяца даты) - (Сумма выплат за все время ДО 1-го числа даты)
  Future<Map<String, double>> getStartingBalances(DateTime date) async {
    final db = await database;
    final year = date.year;
    final month = date.month;

    // 1. Получаем начисления (Сумма за месяцы до текущего)
    final accruedRows = await db.rawQuery(
      '''
      SELECT employee_id, SUM(total_salary) as sum_accrued
      FROM payroll_results
      WHERE year < ? OR (year = ? AND month < ?)
      GROUP BY employee_id
    ''',
      [year, year, month],
    );

    // 2. Получаем выплаты (Сумма до 1-го числа текущего месяца)
    final startOfMonth = formatDateIso(DateTime(year, month, 1));
    final paidRows = await db.rawQuery(
      '''
      SELECT employee_id, SUM(amount) as sum_paid
      FROM payments
      WHERE payment_date < ?
      GROUP BY employee_id
    ''',
      [startOfMonth],
    );

    return payroll.combineBalances(
      accrued: {
        for (final row in accruedRows)
          '${row['employee_id']}': (row['sum_accrued'] as num).toDouble(),
      },
      paid: {
        for (final row in paidRows)
          '${row['employee_id']}': (row['sum_paid'] as num).toDouble(),
      },
    );
  }

  // ==========================================================================
  // ЗАКРЫТИЕ
  // ==========================================================================

  /// Модели хранят id строкой (uuid в схеме v2); старая база ждёт INTEGER.
  /// Временный переходник до переключения на drift (шаг 1.5).
  static void _toLegacyIds(Map<String, dynamic> map) {
    final employeeId = map['employee_id'];
    if (employeeId is String) map['employee_id'] = int.parse(employeeId);
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
