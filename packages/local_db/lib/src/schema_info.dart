// Сведения о схеме v2 для общего кода (конвертер, просмотр базы,
// восстановление из копий), которому нужны таблицы по именам.

/// Бизнес-таблицы с сотрудником из базы v8 (их переносит конвертер) в
/// порядке вставки и их поля-даты
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

/// Все бизнес-таблицы v2 (со служебными полями синхронизации) в порядке
/// вставки: настройки, таблицы с сотрудником (из базы v8), корректировки
/// начисления (схема 3), финансы.
const businessTables = <String>[
  'company_settings',
  ...employeeTablesOrder,
  'payroll_adjustments',
  ...financeTablesOrder,
];

/// Таблицы финансов в порядке вставки.
const financeTablesOrder = <String>[
  'fin_directions',
  'fin_allocation_keys',
  'fin_allocation_periods',
  'fin_accounts',
  'fin_assets',
  'fin_category_groups',
  'fin_categories',
  'counterparties',
  'fin_debts',
  'fin_operations',
  'fin_payroll_mapping',
  'fin_plans',
  'fin_budget',
];

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

/// Таблицы финансов (этап 8, схема 2) и их поля-даты.
const financeTables = <String, List<String>>{
  'fin_directions': [],
  'fin_allocation_keys': [],
  'fin_allocation_periods': ['valid_from'],
  'fin_accounts': ['opening_date'],
  'fin_assets': ['valued_on', 'disposed_on'],
  'fin_category_groups': [],
  'fin_categories': [],
  'counterparties': [],
  'fin_debts': ['opening_date'],
  'fin_plans': ['start_date', 'until_date'],
  'fin_budget': [],
  'fin_operations': ['date'],
  'fin_payroll_mapping': [],
};

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
List<String> dateColumnsOf(String table) =>
    employeeTables[table] ?? financeTables[table] ?? const [];

/// Уникальные ключи среди неудалённых строк (кроме uuid).
const uniqueKeys = <String, List<String>>{
  'timesheet': ['employee_uuid', 'date'],
  'payroll_results': ['employee_uuid', 'year', 'month'],
  'fin_directions': ['name'],
  'fin_allocation_keys': ['name'],
  'fin_allocation_periods': ['key_uuid', 'valid_from'],
  'fin_accounts': ['name'],
  'fin_category_groups': ['type', 'name'],
  'fin_categories': ['type', 'name'],
  'counterparties': ['name'],
  'fin_payroll_mapping': ['kind', 'value'],
  'fin_budget': ['year', 'month', 'category_uuid'],
};

final _identifier = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

/// Имя таблицы или колонки подставляется в SQL — только идентификаторы.
String checkIdentifier(String name) {
  if (!_identifier.hasMatch(name)) {
    throw ArgumentError('Недопустимое имя: $name');
  }
  return name;
}
