import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

/// Сервис для работы с локальной базой данных SQLite
/// Содержит все таблицы для учёта рабочего времени в КФХ
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
      version: 1,
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
    // Вставляем запись по умолчанию
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
        created_at TEXT NOT NULL
      )
    ''');

    // --- Таблица участков/полей ---
    await db.execute('''
      CREATE TABLE work_sites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        area_hectares REAL,
        crop_type TEXT,
        notes TEXT
      )
    ''');

    // --- Таблица видов работ ---
    await db.execute('''
      CREATE TABLE work_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'field',
        default_rate_multiplier REAL,
        notes TEXT
      )
    ''');

    // --- Таблица техники ---
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

    // --- Таблица табеля (основная) ---
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

    // --- Таблица отпусков ---
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

    // --- Таблица больничных ---
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

    // --- Индексы для ускорения запросов ---
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
  }

  /// Обновление базы данных (миграции для будущих версий)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Здесь будут миграции при обновлении версии БД
  }

  // ==========================================================================
  // COMPANY SETTINGS
  // ==========================================================================

  /// Получение настроек КФХ
  Future<CompanySettings?> getCompanySettings() async {
    final db = await database;
    final maps = await db.query('company_settings', where: 'id = 1');
    if (maps.isEmpty) return null;
    return CompanySettings.fromMap(maps.first);
  }

  /// Обновление настроек КФХ
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
  // EMPLOYEES (СОТРУДНИКИ)
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
    if (activeOnly) {
      where = 'WHERE is_active = ?';
    }
    final maps = await db.rawQuery(
      'SELECT * FROM employees $where ORDER BY full_name',
      activeOnly ? [1] : [],
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
  // WORK SITES (УЧАСТКИ)
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
  // WORK TYPES (ВИДЫ РАБОТ)
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
  // MACHINERY (ТЕХНИКА)
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
  // TIMESHEET (ТАБЕЛЬ)
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

  /// Получение записей всех сотрудников за конкретную дату
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
  // PAYMENTS (ВЫПЛАТЫ)
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
  // VACATIONS (ОТПУСКА)
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
  // SICK LEAVES (БОЛЬНИЧНЫЕ)
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
  // ОТЧЁТЫ И РАСЧЁТ ЗАРПЛАТЫ
  // ==========================================================================

  /// Расчёт зарплаты сотрудника за месяц
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

      // Почасовая часть
      double basePay = record.hoursWorked * employee.hourlyRate;
      double overtimePay =
          (record.overtimeHours ?? 0) * employee.hourlyRate * overtimeMult;

      // Сдельная часть
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

    // Выплаты за период
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

  /// Отчёт по выполненным работам по участкам
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

  /// Отчёт по использованию техники
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

  /// Проверка, находится ли сотрудник в отпуске/на больничном
  Future<Map<String, dynamic>?> getEmployeeStatusOnDate(
    int employeeId,
    DateTime date,
  ) async {
    final db = await database;
    final dateStr = date.toIso8601String();

    // Проверяем отпуск
    final vacation = await db.rawQuery(
      '''
      SELECT * FROM vacations
      WHERE employee_id = ? AND start_date <= ? AND end_date >= ?
      LIMIT 1
    ''',
      [employeeId, dateStr, dateStr],
    );

    if (vacation.isNotEmpty) {
      return {'status': 'vacation', 'data': Vacation.fromMap(vacation.first)};
    }

    // Проверяем больничный
    final sickLeave = await db.rawQuery(
      '''
      SELECT * FROM sick_leaves
      WHERE employee_id = ? AND start_date <= ? AND end_date >= ?
      LIMIT 1
    ''',
      [employeeId, dateStr, dateStr],
    );

    if (sickLeave.isNotEmpty) {
      return {
        'status': 'sick_leave',
        'data': SickLeave.fromMap(sickLeave.first),
      };
    }

    return null;
  }

  // ==========================================================================
  // ЗАКРЫТИЕ СОЕДИНЕНИЯ
  // ==========================================================================

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
