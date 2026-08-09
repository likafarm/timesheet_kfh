import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

// ==========================================================================
// ENUMS
// ==========================================================================

/// Статусы работы сотрудника для учёта графиков
enum WorkStatus {
  regularWork, // работа по графику
  regularRest, // отдых по графику
  exceptionWork, // работа вне графика (замена)
  exceptionRest, // отдых вне графика (замена)
  unknown, // обычный сотрудник без графика или ошибка
}

// ==========================================================================
// DATABASE SERVICE
// ==========================================================================

/// Сервис для работы с локальной базой данных SQLite
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  /// Получение экземпляра БД
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Инициализация базы данных
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kfx_time_tracking.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ==========================================================================
  // СОЗДАНИЕ ТАБЛИЦ
  // ==========================================================================

  /// Создание всех таблиц при первом запуске
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
        phone TEXT,
        hire_date TEXT NOT NULL,
        birth_date TEXT,
        passport_series TEXT,
        passport_number TEXT,
        snils TEXT,
        inn TEXT,
        hourly_rate REAL NOT NULL DEFAULT 0,
        fixed_salary REAL,
        payment_type TEXT NOT NULL DEFAULT 'hourly',
        is_active INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        created_at TEXT NOT NULL,
        dismissal_date TEXT,
        dismissal_reason TEXT,
        schedule_type_id INTEGER,
        schedule_start_date TEXT,
        is_shift_worker INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // --- Таблица типов графиков работы ---
    await db.execute('''
      CREATE TABLE work_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        work_days INTEGER NOT NULL,
        rest_days INTEGER NOT NULL,
        shift_duration REAL NOT NULL DEFAULT 24.0
      )
    ''');
    await db.insert('work_schedules', {
      'name': 'Сутки-трое',
      'description': '1 день работы, 3 дня отдыха',
      'work_days': 1,
      'rest_days': 3,
      'shift_duration': 24.0,
    });
    await db.insert('work_schedules', {
      'name': 'Сутки-двое',
      'description': '1 день работы, 2 дня отдыха',
      'work_days': 1,
      'rest_days': 2,
      'shift_duration': 24.0,
    });

    // --- Таблица истории графиков ---
    await db.execute('''
      CREATE TABLE employee_schedule (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        schedule_type_id INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
        FOREIGN KEY (schedule_type_id) REFERENCES work_schedules (id) ON DELETE CASCADE
      )
    ''');

    // --- Таблица исключений ---
    await db.execute('''
      CREATE TABLE schedule_exceptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        exception_type TEXT NOT NULL, -- 'work' или 'rest'
        note TEXT,
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
      )
    ''');

    // --- Участки ---
    await db.execute('''
      CREATE TABLE work_sites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        area_hectares REAL,
        crop_type TEXT,
        notes TEXT
      )
    ''');

    // --- Виды работ ---
    await db.execute('''
      CREATE TABLE work_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'field',
        default_rate_multiplier REAL,
        notes TEXT
      )
    ''');

    // --- Техника ---
    await db.execute('''
      CREATE TABLE machinery (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'tractor',
        registration_number TEXT,
        fuel_consumption_per_hour REAL,
        is_active INTEGER NOT NULL DEFAULT 1,
        notes TEXT
      )
    ''');

    // --- Табель ---
    await db.execute('''
      CREATE TABLE timesheet (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        hours_worked REAL NOT NULL DEFAULT 0,
        overtime_hours REAL,
        work_type_id INTEGER,
        work_site_id INTEGER,
        machinery_id INTEGER,
        quantity_done REAL,
        quantity_unit TEXT,
        piecework_rate REAL,
        bonus REAL,
        penalty REAL,
        weather_condition TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
        FOREIGN KEY (work_type_id) REFERENCES work_types (id) ON DELETE SET NULL,
        FOREIGN KEY (work_site_id) REFERENCES work_sites (id) ON DELETE SET NULL,
        FOREIGN KEY (machinery_id) REFERENCES machinery (id) ON DELETE SET NULL
      )
    ''');

    // --- Выплаты ---
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

    // --- Отпуска ---
    await db.execute('''
      CREATE TABLE vacations (
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

    // --- Больничные ---
    await db.execute('''
      CREATE TABLE sick_leaves (
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

    // --- Производственный календарь ---
    await db.execute('''
      CREATE TABLE production_calendar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        is_holiday INTEGER NOT NULL DEFAULT 0,
        is_shortened INTEGER NOT NULL DEFAULT 0,
        description TEXT
      )
    ''');

    // --- Индексы ---
    await db.execute('CREATE INDEX idx_timesheet_date ON timesheet(date)');
    await db.execute(
      'CREATE INDEX idx_timesheet_employee ON timesheet(employee_id)',
    );
    await db.execute(
      'CREATE INDEX idx_timesheet_emp_date ON timesheet(employee_id, date)',
    );
    await db.execute(
      'CREATE INDEX idx_payments_employee ON payments(employee_id)',
    );
    await db.execute(
      'CREATE INDEX idx_payments_date ON payments(payment_date)',
    );
    await db.execute(
      'CREATE INDEX idx_vacations_employee ON vacations(employee_id)',
    );
    await db.execute(
      'CREATE INDEX idx_sick_leaves_employee ON sick_leaves(employee_id)',
    );
    await db.execute(
      'CREATE INDEX idx_calendar_date ON production_calendar(date)',
    );
    await db.execute(
      'CREATE INDEX idx_employee_schedule_employee ON employee_schedule(employee_id)',
    );
    await db.execute(
      'CREATE INDEX idx_schedule_exceptions_employee ON schedule_exceptions(employee_id)',
    );
    await db.execute(
      'CREATE INDEX idx_schedule_exceptions_date ON schedule_exceptions(date)',
    );
  }

  /// Обновление базы данных (миграции)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE employees ADD COLUMN dismissal_date TEXT',
        );
        await db.execute(
          'ALTER TABLE employees ADD COLUMN dismissal_reason TEXT',
        );
      } catch (e) {
        // ignore: empty_catches
        // Столбцы уже существуют
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute(
          'ALTER TABLE employees ADD COLUMN schedule_type_id INTEGER',
        );
        await db.execute(
          'ALTER TABLE employees ADD COLUMN schedule_start_date TEXT',
        );
        await db.execute(
          'ALTER TABLE employees ADD COLUMN is_shift_worker INTEGER NOT NULL DEFAULT 0',
        );

        await db.execute('''
          CREATE TABLE work_schedules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            work_days INTEGER NOT NULL,
            rest_days INTEGER NOT NULL,
            shift_duration REAL NOT NULL DEFAULT 24.0
          )
        ''');
        await db.insert('work_schedules', {
          'name': 'Сутки-трое',
          'description': '1 день работы, 3 дня отдыха',
          'work_days': 1,
          'rest_days': 3,
          'shift_duration': 24.0,
        });
        await db.insert('work_schedules', {
          'name': 'Сутки-двое',
          'description': '1 день работы, 2 дня отдыха',
          'work_days': 1,
          'rest_days': 2,
          'shift_duration': 24.0,
        });

        await db.execute('''
          CREATE TABLE employee_schedule (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            employee_id INTEGER NOT NULL,
            schedule_type_id INTEGER NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT,
            FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
            FOREIGN KEY (schedule_type_id) REFERENCES work_schedules (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE schedule_exceptions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            employee_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            exception_type TEXT NOT NULL,
            note TEXT,
            FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE production_calendar (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL UNIQUE,
            is_holiday INTEGER NOT NULL DEFAULT 0,
            is_shortened INTEGER NOT NULL DEFAULT 0,
            description TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_calendar_date ON production_calendar(date)',
        );
        await db.execute(
          'CREATE INDEX idx_employee_schedule_employee ON employee_schedule(employee_id)',
        );
        await db.execute(
          'CREATE INDEX idx_schedule_exceptions_employee ON schedule_exceptions(employee_id)',
        );
        await db.execute(
          'CREATE INDEX idx_schedule_exceptions_date ON schedule_exceptions(date)',
        );
      } catch (e) {
        // ignore: empty_catches
        // Таблицы или столбцы уже существуют
      }
    }
  }

  // ==========================================================================
  // COMPANY SETTINGS
  // ==========================================================================

  Future<CompanySettings?> getCompanySettings() async {
    final db = await database;
    final maps = await db.query('company_settings', where: 'id = 1');
    if (maps.isEmpty) return null;
    return CompanySettings.fromMap(maps.first);
  }

  Future<int> updateCompanySettings(CompanySettings settings) async {
    final db = await database;
    return await db.update(
      'company_settings',
      settings.toMap(),
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  // ==========================================================================
  // EMPLOYEES
  // ==========================================================================

  Future<int> insertEmployee(Employee employee) async {
    final db = await database;
    final map = employee.toMap();
    map.remove('id');
    map['created_at'] = DateTime.now().toIso8601String();
    return await db.insert('employees', map);
  }

  Future<List<Employee>> getAllEmployees({bool activeOnly = false}) async {
    final db = await database;
    String where = '';
    List<dynamic> whereArgs = [];
    if (activeOnly) {
      where = 'WHERE is_active = ?';
      whereArgs = [1];
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
    return await db.update(
      'employees',
      employee.toMap(),
      where: 'id = ?',
      whereArgs: [employee.id],
    );
  }

  Future<int> deleteEmployee(int id) async {
    final db = await database;
    return await db.delete('employees', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================================================
  // WORK SCHEDULES
  // ==========================================================================

  Future<List<Map<String, dynamic>>> getWorkScheduleTypes() async {
    final db = await database;
    return await db.query('work_schedules', orderBy: 'name');
  }

  /// Получить текущий график сотрудника (активный или последний)
  Future<Map<String, dynamic>?> getEmployeeCurrentSchedule(
    int employeeId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'employee_schedule',
      where:
          'employee_id = ? AND (end_date IS NULL OR end_date >= date(\'now\'))', // исправлено кавычки
      whereArgs: [employeeId],
      orderBy: 'start_date DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<int> assignEmployeeSchedule(
    int employeeId,
    int scheduleTypeId,
    DateTime startDate,
  ) async {
    final db = await database;
    final map = {
      'employee_id': employeeId,
      'schedule_type_id': scheduleTypeId,
      'start_date': startDate.toIso8601String(),
    };
    return await db.insert('employee_schedule', map);
  }

  Future<int> closeEmployeeSchedule(int scheduleId, DateTime endDate) async {
    final db = await database;
    return await db.update(
      'employee_schedule',
      {'end_date': endDate.toIso8601String()},
      where: 'id = ?',
      whereArgs: [scheduleId],
    );
  }

  // ==========================================================================
  // SCHEDULE EXCEPTIONS
  // ==========================================================================

  Future<int> addScheduleException(
    int employeeId,
    DateTime date,
    String exceptionType, {
    String? note,
  }) async {
    final db = await database;
    final map = {
      'employee_id': employeeId,
      'date': date.toIso8601String(),
      'exception_type': exceptionType,
      'note': note,
    };
    return await db.insert('schedule_exceptions', map);
  }

  Future<int> deleteScheduleException(int id) async {
    final db = await database;
    return await db.delete(
      'schedule_exceptions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getScheduleExceptionsForEmployee(
    int employeeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    String where = 'employee_id = ?';
    List<dynamic> whereArgs = [employeeId];
    if (startDate != null && endDate != null) {
      where += ' AND date >= ? AND date <= ?';
      whereArgs.add(startDate.toIso8601String());
      whereArgs.add(endDate.toIso8601String());
    }
    return await db.query(
      'schedule_exceptions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'date',
    );
  }

  // ==========================================================================
  // ОПРЕДЕЛЕНИЕ СТАТУСА СОТРУДНИКА
  // ==========================================================================

  Future<WorkStatus> getEmployeeStatusOnDate(
    int employeeId,
    DateTime date,
  ) async {
    final db = await database;
    final dateStr = date.toIso8601String();

    final exception = await db.query(
      'schedule_exceptions',
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, dateStr],
      limit: 1,
    );
    if (exception.isNotEmpty) {
      return exception.first['exception_type'] == 'work'
          ? WorkStatus.exceptionWork
          : WorkStatus.exceptionRest;
    }

    final employee = await getEmployeeById(employeeId);
    if (employee == null || !employee.isShiftWorker) {
      return WorkStatus.unknown;
    }

    final schedule = await getEmployeeCurrentSchedule(employeeId);
    if (schedule == null) {
      return WorkStatus.unknown;
    }

    final scheduleTypeId = schedule['schedule_type_id'] as int;
    final startDate = DateTime.parse(schedule['start_date'] as String);

    final type = await db.query(
      'work_schedules',
      where: 'id = ?',
      whereArgs: [scheduleTypeId],
    );
    if (type.isEmpty) return WorkStatus.unknown;
    final workDays = type.first['work_days'] as int;
    final restDays = type.first['rest_days'] as int;
    final cycleDays = workDays + restDays;

    final daysSinceStart = date.difference(startDate).inDays;
    final positionInCycle = daysSinceStart % cycleDays;

    return positionInCycle < workDays
        ? WorkStatus.regularWork
        : WorkStatus.regularRest;
  }

  // ==========================================================================
  // WORK SITES
  // ==========================================================================

  Future<int> insertWorkSite(WorkSite site) async {
    final db = await database;
    final map = site.toMap();
    map.remove('id');
    return await db.insert('work_sites', map);
  }

  Future<List<WorkSite>> getAllWorkSites() async {
    final db = await database;
    final maps = await db.query('work_sites', orderBy: 'name');
    return maps.map((m) => WorkSite.fromMap(m)).toList();
  }

  Future<WorkSite?> getWorkSiteById(int id) async {
    final db = await database;
    final maps = await db.query('work_sites', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return WorkSite.fromMap(maps.first);
  }

  Future<int> updateWorkSite(WorkSite site) async {
    final db = await database;
    return await db.update(
      'work_sites',
      site.toMap(),
      where: 'id = ?',
      whereArgs: [site.id],
    );
  }

  Future<int> deleteWorkSite(int id) async {
    final db = await database;
    return await db.delete('work_sites', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================================================
  // WORK TYPES
  // ==========================================================================

  Future<int> insertWorkType(WorkType workType) async {
    final db = await database;
    final map = workType.toMap();
    map.remove('id');
    return await db.insert('work_types', map);
  }

  Future<List<WorkType>> getAllWorkTypes() async {
    final db = await database;
    final maps = await db.query('work_types', orderBy: 'name');
    return maps.map((m) => WorkType.fromMap(m)).toList();
  }

  Future<WorkType?> getWorkTypeById(int id) async {
    final db = await database;
    final maps = await db.query('work_types', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return WorkType.fromMap(maps.first);
  }

  Future<int> updateWorkType(WorkType workType) async {
    final db = await database;
    return await db.update(
      'work_types',
      workType.toMap(),
      where: 'id = ?',
      whereArgs: [workType.id],
    );
  }

  Future<int> deleteWorkType(int id) async {
    final db = await database;
    return await db.delete('work_types', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================================================
  // MACHINERY
  // ==========================================================================

  Future<int> insertMachinery(Machinery machinery) async {
    final db = await database;
    final map = machinery.toMap();
    map.remove('id');
    return await db.insert('machinery', map);
  }

  Future<List<Machinery>> getAllMachinery({bool activeOnly = false}) async {
    final db = await database;
    String where = '';
    if (activeOnly) {
      where = 'WHERE is_active = ?';
    }
    final maps = await db.rawQuery(
      'SELECT * FROM machinery $where ORDER BY name',
      activeOnly ? [1] : [],
    );
    return maps.map((m) => Machinery.fromMap(m)).toList();
  }

  Future<Machinery?> getMachineryById(int id) async {
    final db = await database;
    final maps = await db.query('machinery', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Machinery.fromMap(maps.first);
  }

  Future<int> updateMachinery(Machinery machinery) async {
    final db = await database;
    return await db.update(
      'machinery',
      machinery.toMap(),
      where: 'id = ?',
      whereArgs: [machinery.id],
    );
  }

  Future<int> deleteMachinery(int id) async {
    final db = await database;
    return await db.delete('machinery', where: 'id = ?', whereArgs: [id]);
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

  Future<List<TimesheetRecord>> getEmployeeMonthlyTimesheet(
    int employeeId,
    int year,
    int month,
  ) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    return getTimesheetByPeriod(start, end, employeeId: employeeId);
  }

  Future<List<Map<String, dynamic>>> getDailyTimesheet(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    return await db.rawQuery(
      '''
      SELECT 
        e.id as employee_id,
        e.full_name,
        e.position,
        e.hourly_rate,
        t.id as record_id,
        t.hours_worked,
        t.overtime_hours,
        t.work_type_id,
        t.work_site_id,
        t.machinery_id,
        t.quantity_done,
        t.quantity_unit,
        t.piecework_rate,
        t.bonus,
        t.penalty,
        t.weather_condition,
        t.notes as record_notes
      FROM employees e
      LEFT JOIN timesheet t ON e.id = t.employee_id 
        AND t.date LIKE ?
      WHERE e.is_active = 1
      ORDER BY e.full_name
    ''',
      ['$dateStr%'],
    );
  }

  Future<int> updateTimesheetRecord(TimesheetRecord record) async {
    final db = await database;
    final map = record.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
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

  Future<int> updatePayment(Payment payment) async {
    final db = await database;
    return await db.update(
      'payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  Future<int> deletePayment(int id) async {
    final db = await database;
    return await db.delete('payments', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================================================
  // VACATIONS
  // ==========================================================================

  Future<int> insertVacation(Vacation vacation) async {
    final db = await database;
    final map = vacation.toMap();
    map.remove('id');
    return await db.insert('vacations', map);
  }

  Future<List<Vacation>> getVacationsByEmployee(int employeeId) async {
    final db = await database;
    final maps = await db.query(
      'vacations',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'start_date DESC',
    );
    return maps.map((m) => Vacation.fromMap(m)).toList();
  }

  Future<List<Vacation>> getVacationsByPeriod(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT * FROM vacations
      WHERE (start_date <= ? AND end_date >= ?)
      ORDER BY start_date DESC
    ''',
      [end.toIso8601String(), start.toIso8601String()],
    );
    return maps.map((m) => Vacation.fromMap(m)).toList();
  }

  Future<int> updateVacation(Vacation vacation) async {
    final db = await database;
    return await db.update(
      'vacations',
      vacation.toMap(),
      where: 'id = ?',
      whereArgs: [vacation.id],
    );
  }

  Future<int> deleteVacation(int id) async {
    final db = await database;
    return await db.delete('vacations', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================================================
  // SICK LEAVES
  // ==========================================================================

  Future<int> insertSickLeave(SickLeave sickLeave) async {
    final db = await database;
    final map = sickLeave.toMap();
    map.remove('id');
    return await db.insert('sick_leaves', map);
  }

  Future<List<SickLeave>> getSickLeavesByEmployee(int employeeId) async {
    final db = await database;
    final maps = await db.query(
      'sick_leaves',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'start_date DESC',
    );
    return maps.map((m) => SickLeave.fromMap(m)).toList();
  }

  Future<int> updateSickLeave(SickLeave sickLeave) async {
    final db = await database;
    return await db.update(
      'sick_leaves',
      sickLeave.toMap(),
      where: 'id = ?',
      whereArgs: [sickLeave.id],
    );
  }

  Future<int> deleteSickLeave(int id) async {
    final db = await database;
    return await db.delete('sick_leaves', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================================================
  // PRODUCTION CALENDAR
  // ==========================================================================

  Future<void> saveCalendarDay(
    DateTime date,
    bool isHoliday,
    bool isShortened, {
    String? description,
  }) async {
    final db = await database;
    final map = {
      'date': date.toIso8601String(),
      'is_holiday': isHoliday ? 1 : 0,
      'is_shortened': isShortened ? 1 : 0,
      'description': description,
    };
    await db.insert(
      'production_calendar',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getCalendarDay(DateTime date) async {
    final db = await database;
    final maps = await db.query(
      'production_calendar',
      where: 'date = ?',
      whereArgs: [date.toIso8601String()],
    );
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<List<Map<String, dynamic>>> getCalendarForPeriod(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    return await db.query(
      'production_calendar',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date',
    );
  }

  // ==========================================================================
  // ОТЧЁТЫ
  // ==========================================================================

  Future<Map<String, dynamic>> calculateMonthlySalary(
    int employeeId,
    int year,
    int month,
  ) async {
    final records = await getEmployeeMonthlyTimesheet(employeeId, year, month);
    final employee = await getEmployeeById(employeeId);
    final settings = await getCompanySettings();

    if (employee == null) {
      throw Exception('Сотрудник не найден');
    }

    double totalHours = 0;
    double totalOvertime = 0;
    double totalQuantity = 0;
    double totalPiecework = 0;
    double totalBonus = 0;
    double totalPenalty = 0;
    double totalSalary = 0;

    final overtimeMult = settings?.overtimeMultiplier ?? 1.5;

    for (final record in records) {
      totalHours += record.hoursWorked;
      totalOvertime += record.overtimeHours ?? 0;
      totalBonus += record.bonus ?? 0;
      totalPenalty += record.penalty ?? 0;

      double basePay = record.hoursWorked * employee.hourlyRate;
      double overtimePay =
          (record.overtimeHours ?? 0) * employee.hourlyRate * overtimeMult;

      double pieceworkPay = 0;
      if (record.quantityDone != null && record.pieceworkRate != null) {
        pieceworkPay = record.quantityDone! * record.pieceworkRate!;
        totalQuantity += record.quantityDone!;
        totalPiecework += pieceworkPay;
      }

      totalSalary +=
          basePay +
          overtimePay +
          pieceworkPay +
          (record.bonus ?? 0) -
          (record.penalty ?? 0);
    }

    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    final payments = await getPaymentsByEmployee(
      employeeId,
      startDate: start,
      endDate: end,
    );
    double totalPaid = payments.fold(0, (sum, p) => sum + p.amount);

    return {
      'employee': employee,
      'records': records,
      'totalHours': totalHours,
      'totalOvertime': totalOvertime,
      'totalQuantity': totalQuantity,
      'totalPiecework': totalPiecework,
      'totalBonus': totalBonus,
      'totalPenalty': totalPenalty,
      'totalSalary': totalSalary,
      'totalPaid': totalPaid,
      'balance': totalSalary - totalPaid,
    };
  }

  Future<List<Map<String, dynamic>>> getWorkReportBySites(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT 
        ws.name as site_name,
        wt.name as work_type_name,
        SUM(t.quantity_done) as total_quantity,
        t.quantity_unit,
        SUM(t.hours_worked) as total_hours,
        COUNT(DISTINCT t.employee_id) as workers_count
      FROM timesheet t
      LEFT JOIN work_sites ws ON t.work_site_id = ws.id
      LEFT JOIN work_types wt ON t.work_type_id = wt.id
      WHERE t.date >= ? AND t.date <= ?
      GROUP BY t.work_site_id, t.work_type_id
      ORDER BY ws.name, wt.name
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
  }

  Future<List<Map<String, dynamic>>> getMachineryReport(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT 
        m.name as machinery_name,
        m.registration_number,
        m.type,
        COUNT(DISTINCT t.date) as days_used,
        SUM(t.hours_worked) as total_hours,
        SUM(t.hours_worked * COALESCE(m.fuel_consumption_per_hour, 0)) as estimated_fuel
      FROM timesheet t
      JOIN machinery m ON t.machinery_id = m.id
      WHERE t.date >= ? AND t.date <= ?
      GROUP BY m.id
      ORDER BY m.name
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
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
