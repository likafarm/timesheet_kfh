// Сведения о схеме v2 для общего кода (конвертер, просмотр базы,
// восстановление из копий), которому нужны таблицы по именам.

/// Бизнес-таблицы с сотрудником в порядке вставки и их поля-даты
/// (`гггг-мм-дд`). `company_settings` — отдельно: одна строка, без дат.
const employeeTables = <String, List<String>>{
  'employees': ['hire_date', 'dismissal_date'],
  'employee_rates': ['start_date', 'end_date'],
  'timesheet': ['date'],
  'payments': ['payment_date', 'period_start', 'period_end'],
  'sick_leave': ['start_date', 'end_date'],
  'vacation': ['start_date', 'end_date'],
  'payroll_results': [],
};

/// Все бизнес-таблицы v2 (со служебными полями синхронизации).
const businessTables = <String>['company_settings', ...employeeTablesOrder];

/// Таблицы с сотрудником в порядке вставки (сначала employees).
const employeeTablesOrder = <String>[
  'employees',
  'employee_rates',
  'timesheet',
  'payments',
  'sick_leave',
  'vacation',
  'payroll_results',
];

/// Служебные поля синхронизации — вручную не правятся.
const syncColumns = <String>{
  'uuid',
  'legacy_id',
  'updated_at',
  'deleted',
  'edited_by',
  'remote_updated_at',
};

/// Поля-даты (`гггг-мм-дд`) таблицы; пусто — дат нет или таблица не бизнес.
List<String> dateColumnsOf(String table) => employeeTables[table] ?? const [];

/// Уникальные ключи среди неудалённых строк (кроме uuid).
const uniqueKeys = <String, List<String>>{
  'timesheet': ['employee_uuid', 'date'],
  'payroll_results': ['employee_uuid', 'year', 'month'],
};

final _identifier = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

/// Имя таблицы или колонки подставляется в SQL — только идентификаторы.
String checkIdentifier(String name) {
  if (!_identifier.hasMatch(name)) {
    throw ArgumentError('Недопустимое имя: $name');
  }
  return name;
}
