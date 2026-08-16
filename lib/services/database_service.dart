// lib/services/database_service.dart

import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';
import '../models/employee_rate.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kfx_time_tracking.db');
    return await openDatabase(
      path,
      version: 7, // увеличена для таблицы payroll_results
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
  }

  // ==========================================================================
  // EMPLOYEES (без изменений)
  // ==========================================================================

  Future<int> insertEmployee(Employee employee) async {
    final db = await database;
    final map = employee.toMap();
    map.remove('id');
    return await db.insert('employees', map);
  }

  Future<List<Employee>> getAllEmployees({bool activeOnly = false}) async {
    final db = await database;
    String where = '';
    List<dynamic> whereArgs = [];
    if (activeOnly) {
      where = 'WHERE dismissal_date IS NULL OR dismissal_date > ?';
      whereArgs = [DateTime.now().toIso8601String()];
    }
    final maps = await db.rawQuery(
      'SELECT * FROM employees $where ORDER BY full_name',
      whereArgs,
    );
    return maps.map((m) => Employee.fromMap(m)).toList();
  }

  Future<Employee?> getEmployeeById(int id) async {
    final db = await database;
    final maps = await db.query('employees', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Employee.fromMap(maps.first);
  }

  Future<int> updateEmployee(Employee employee) async {
    final db = await database;
    final map = employee.toMap();
    map.remove('id');
    return await db.update(
      'employees',
      map,
      where: 'id = ?',
      whereArgs: [employee.id],
    );
  }

  Future<int> deleteEmployee(int id) async {
    final db = await database;
    return await db.delete('employees', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================================================
  // EMPLOYEE RATES (без изменений)
  // ==========================================================================

  Future<int> _insertEmployeeRate(EmployeeRate rate) async {
    final db = await database;
    final map = rate.toMap();
    map.remove('id');
    return await db.insert('employee_rates', map);
  }

  Future<int> insertEmployeeRate(EmployeeRate rate) async {
    final db = await database;
    final current = await db.query(
      'employee_rates',
      where: 'employee_id = ? AND end_date IS NULL',
      whereArgs: [rate.employeeId],
    );
    if (current.isNotEmpty) {
      await db.update(
        'employee_rates',
        {
          'end_date': rate.startDate
              .subtract(const Duration(days: 1))
              .toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [current.first['id']],
      );
    }
    return await _insertEmployeeRate(rate);
  }

  Future<List<EmployeeRate>> getEmployeeRateHistory(int employeeId) async {
    final db = await database;
    final maps = await db.query(
      'employee_rates',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'start_date ASC',
    );
    return maps.map((m) => EmployeeRate.fromMap(m)).toList();
  }

  Future<EmployeeRate?> getEmployeeRateAtDate(
    int employeeId,
    DateTime date,
  ) async {
    final db = await database;
    final dateStr = date.toIso8601String();
    final maps = await db.query(
      'employee_rates',
      where:
          'employee_id = ? AND start_date <= ? AND (end_date IS NULL OR end_date >= ?)',
      whereArgs: [employeeId, dateStr, dateStr],
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
    map['created_at'] = DateTime.now().toIso8601String();
    return await db.insert('timesheet', map);
  }

  Future<List<TimesheetRecord>> getTimesheetByPeriod(
    DateTime start,
    DateTime end, {
    int? employeeId,
  }) async {
    final db = await database;
    String where = 'date >= ? AND date <= ?';
    List<dynamic> whereArgs = [start.toIso8601String(), end.toIso8601String()];
    if (employeeId != null) {
      where += ' AND employee_id = ?';
      whereArgs.add(employeeId);
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
    int employeeId,
    DateTime date,
  ) async {
    final db = await database;
    final dateStr = date.toIso8601String();
    final maps = await db.query(
      'timesheet',
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, dateStr],
    );
    if (maps.isEmpty) return null;
    return TimesheetRecord.fromMap(maps.first);
  }

  Future<int> updateTimesheetRecord(TimesheetRecord record) async {
    final db = await database;
    final map = record.toMap();
    map.remove('id');
    return await db.update(
      'timesheet',
      map,
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteTimesheetRecord(int id) async {
    final db = await database;
    return await db.delete('timesheet', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================================================
  // PAYMENTS (без изменений)
  // ==========================================================================

  Future<int> insertPayment(Payment payment) async {
    final db = await database;
    final map = payment.toMap();
    map.remove('id');
    map['created_at'] = DateTime.now().toIso8601String();
    return await db.insert('payments', map);
  }

  Future<List<Payment>> getPaymentsByEmployee(
    int employeeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    String where = 'employee_id = ?';
    List<dynamic> whereArgs = [employeeId];
    if (startDate != null && endDate != null) {
      where += ' AND payment_date >= ? AND payment_date <= ?';
      whereArgs.add(startDate.toIso8601String());
      whereArgs.add(endDate.toIso8601String());
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
      where += ' AND payment_date >= ? AND payment_date <= ?';
      whereArgs.add(startDate.toIso8601String());
      whereArgs.add(endDate.toIso8601String());
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
    return await db.update(
      'payments',
      map,
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  Future<int> deletePayment(int id) async {
    final db = await database;
    return await db.delete('payments', where: 'id = ?', whereArgs: [id]);
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
    int employeeId,
    int year,
    int month,
  ) async {
    final employee = await getEmployeeById(employeeId);
    if (employee == null) throw Exception('Сотрудник не найден');

    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);

    final records = await getTimesheetByPeriod(
      start,
      end,
      employeeId: employeeId,
    );

    double totalBaseDays = 0.0;
    double totalFieldDays = 0.0;
    double sickDays = 0.0;
    double vacationDays = 0.0;
    double totalSalary = 0.0;
    double? lastBaseRate;
    double? lastFieldRate;

    for (var record in records) {
      if (record.dayType == 'work') {
        final rate = await getEmployeeRateAtDate(employeeId, record.date);
        if (rate == null) continue;
        lastBaseRate = rate.baseRate;
        lastFieldRate = rate.fieldRate;
        final dayRate = record.workPlace == 'base'
            ? rate.baseRate
            : rate.fieldRate;
        totalSalary += record.days * dayRate;
        if (record.workPlace == 'base') {
          totalBaseDays += record.days;
        } else if (record.workPlace == 'field') {
          totalFieldDays += record.days;
        }
      } else if (record.dayType == 'sick') {
        sickDays += record.days;
      } else if (record.dayType == 'vacation') {
        vacationDays += record.days;
      }
    }

    return {
      'employeeId': employeeId,
      'year': year,
      'month': month,
      'baseDays': totalBaseDays,
      'fieldDays': totalFieldDays,
      'sickDays': sickDays,
      'vacationDays': vacationDays,
      'totalSalary': totalSalary,
      'baseRateUsed': lastBaseRate,
      'fieldRateUsed': lastFieldRate,
    };
  }

  /// Сохраняет или обновляет результат расчёта
  Future<int> savePayrollResult(PayrollResult result) async {
    final db = await database;
    final map = result.toMap();
    map.remove('id');

    final existing = await db.query(
      'payroll_results',
      where: 'employee_id = ? AND year = ? AND month = ?',
      whereArgs: [result.employeeId, result.year, result.month],
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
    int employeeId,
    int year,
    int month,
  ) async {
    final db = await database;
    final maps = await db.query(
      'payroll_results',
      where: 'employee_id = ? AND year = ? AND month = ?',
      whereArgs: [employeeId, year, month],
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
    int employeeId,
    int year,
    int month,
  ) async {
    final db = await database;
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    final maps = await db.query(
      'timesheet',
      where: 'employee_id = ? AND date >= ? AND date <= ?',
      whereArgs: [employeeId, start.toIso8601String(), end.toIso8601String()],
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
    int employeeId,
    int year,
    int month,
  ) async {
    // Можно удалить или оставить для обратной совместимости
    return await calculateMonthlySalaryDetailed(employeeId, year, month);
  }

  // ==========================================================================
  // ЗАКРЫТИЕ
  // ==========================================================================

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
