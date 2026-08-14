// lib/services/database_service.dart

import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';
import '../models/employee_rate.dart';

// ==========================================================================
// DATABASE SERVICE
// ==========================================================================

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
      version: 5, // увеличена версия
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ==========================================================================
  // СОЗДАНИЕ ТАБЛИЦ
  // ==========================================================================

  Future<void> _onCreate(Database db, int version) async {
    // --- Таблица настроек КФХ ---
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

    // --- Таблица сотрудников ---
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

    // --- Таблица истории изменения окладов ---
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

    // --- Таблица табеля ---
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

    // --- Таблица выплат ---
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

    // --- Индексы ---
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_timesheet_employee_date ON timesheet(employee_id, date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_timesheet_date ON timesheet(date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_employee_date ON payments(employee_id, payment_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_employee_rates_employee ON employee_rates(employee_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_employee_rates_active ON employee_rates(employee_id, start_date, end_date)',
    );
  }

  // ==========================================================================
  // МИГРАЦИЯ с версии 4 на 5 (добавление company_settings)
  // ==========================================================================

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      // Миграция с 3 на 4 (уже была)
      // ...
    }
    if (oldVersion < 5) {
      // Создаём таблицу настроек
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
    }
  }

  // ==========================================================================
  // EMPLOYEES (без изменений)
  // ==========================================================================

  Future<int> insertEmployee(Employee employee) async {
    final db = await database;
    final map = employee.toMap();
    map.remove('id');
    final id = await db.insert('employees', map);
    await _insertEmployeeRate(
      EmployeeRate(
        employeeId: id,
        baseRate: employee.baseRate,
        fieldRate: employee.fieldRate,
        startDate: employee.hireDate,
      ),
    );
    return id;
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
  // EMPLOYEE RATES
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
  // TIMESHEET
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
  // PAYMENTS
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
  // COMPANY SETTINGS (новые методы)
  // ==========================================================================

  Future<Map<String, dynamic>?> getCompanySettings() async {
    final db = await database;
    final maps = await db.query('company_settings', where: 'id = 1');
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<int> updateCompanySettings(Map<String, dynamic> settings) async {
    final db = await database;
    settings.remove('id'); // защита от изменения id
    return await db.update(
      'company_settings',
      settings,
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  // ==========================================================================
  // ДОПОЛНИТЕЛЬНЫЕ МЕТОДЫ ДЛЯ ПРОСМОТРА БАЗЫ ДАННЫХ
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
    if (sets.isEmpty) {
      throw Exception('Нет данных для обновления');
    }
    values.add(id);
    final query = 'UPDATE $tableName SET ${sets.join(', ')} WHERE id = ?';
    await db.rawUpdate(query, values);
  }

  Future<void> deleteRow(String tableName, int id) async {
    final db = await database;
    if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(tableName)) {
      throw Exception('Недопустимое имя таблицы');
    }
    await db.rawDelete('DELETE FROM $tableName WHERE id = ?', [id]);
  }

  // ==========================================================================
  // РАСЧЁТ ЗАРПЛАТЫ
  // ==========================================================================

  Future<Map<String, dynamic>> calculateMonthlySalary(
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

    for (var r in records) {
      if (r.dayType == 'work') {
        if (r.workPlace == 'base') {
          totalBaseDays += r.days;
        } else if (r.workPlace == 'field') {
          totalFieldDays += r.days;
        }
      } else if (r.dayType == 'sick') {
        sickDays += r.days;
      } else if (r.dayType == 'vacation') {
        vacationDays += r.days;
      }
    }

    final rate = await getEmployeeRateAtDate(employeeId, end);
    if (rate == null) throw Exception('Ставка не найдена');

    final baseRate = rate.baseRate;
    final fieldRate = rate.fieldRate;

    final totalSalary =
        (totalBaseDays * baseRate) + (totalFieldDays * fieldRate);

    final payments = await getPaymentsByEmployee(
      employeeId,
      startDate: start,
      endDate: end,
    );
    final totalPaid = payments.fold(0.0, (sum, p) => sum + p.amount);

    return {
      'employee': employee,
      'records': records,
      'totalBaseDays': totalBaseDays,
      'totalFieldDays': totalFieldDays,
      'sickDays': sickDays,
      'vacationDays': vacationDays,
      'baseRate': baseRate,
      'fieldRate': fieldRate,
      'totalSalary': totalSalary,
      'totalPaid': totalPaid,
      'balance': totalSalary - totalPaid,
    };
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
