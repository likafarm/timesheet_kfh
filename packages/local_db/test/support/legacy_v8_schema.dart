// Схема старой базы v8 — копия DatabaseService._onCreate (sqflite).
// Нужна тестам конвертера; после перехода на drift старого кода не будет.

const legacyV8Schema = <String>[
  '''
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
''',
  '''
CREATE TABLE employees (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    full_name TEXT NOT NULL,
    position TEXT NOT NULL,
    hire_date TEXT NOT NULL,
    dismissal_date TEXT,
    base_rate REAL NOT NULL DEFAULT 0,
    field_rate REAL NOT NULL DEFAULT 0
  )
''',
  '''
CREATE TABLE employee_rates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL,
    base_rate REAL NOT NULL,
    field_rate REAL NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT,
    FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
  )
''',
  '''
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
''',
  '''
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
''',
  '''
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
''',
  '''
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
''',
  '''
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
''',
  '''
CREATE UNIQUE INDEX idx_payroll_unique ON payroll_results(employee_id, year, month)
''',
  '''
CREATE INDEX idx_timesheet_employee_date ON timesheet(employee_id, date)
''',
  '''
CREATE INDEX idx_timesheet_date ON timesheet(date)
''',
  '''
CREATE INDEX idx_payments_employee_date ON payments(employee_id, payment_date)
''',
  '''
CREATE INDEX idx_employee_rates_employee ON employee_rates(employee_id)
''',
  '''
CREATE INDEX idx_employee_rates_active ON employee_rates(employee_id, start_date, end_date)
''',
  '''
CREATE UNIQUE INDEX idx_timesheet_unique ON timesheet(employee_id, date)
''',
];
