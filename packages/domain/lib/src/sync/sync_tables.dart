// Состав синхронизируемых таблиц — общий для клиента и сервера формат
// обмена. Совпадение с локальной схемой (drift) проверяет тест пакета
// local_db, с MySQL — тест сервера.
//
// Служебные поля (uuid, updated_at, deleted, edited_by) передаются в
// изменении отдельно (см. SyncChange), здесь — только данные записи и
// legacy_id.

/// Тип значения в JSON обмена.
enum SyncType {
  /// Строка.
  text,

  /// uuid (строчные hex с дефисами) — ссылка на другую запись.
  uuid,

  /// День `гггг-мм-дд`.
  date,

  /// Число с плавающей точкой (JSON number).
  real,

  /// Целое (JSON integer).
  integer,

  /// true / false.
  boolean,
}

class SyncColumn {
  final String name;
  final SyncType type;
  final bool nullable;

  /// Наибольшая длина строки (символов).
  final int? maxLength;

  /// Допустимые значения строки; null — любые.
  final Set<String>? allowed;

  /// Границы числа (включительно).
  final num? min;
  final num? max;

  const SyncColumn(
    this.name,
    this.type, {
    this.nullable = false,
    this.maxLength,
    this.allowed,
    this.min,
    this.max,
  });
}

class SyncTable {
  final String name;
  final List<SyncColumn> columns;

  const SyncTable(this.name, this.columns);

  /// Колонка по имени или null.
  SyncColumn? column(String name) {
    for (final c in columns) {
      if (c.name == name) return c;
    }
    return null;
  }

  Iterable<String> get columnNames => columns.map((c) => c.name);

  /// Ссылается ли таблица на сотрудника.
  bool get hasEmployee => column('employee_uuid') != null;
}

const _legacyId = SyncColumn('legacy_id', SyncType.integer, nullable: true);
const _employee = SyncColumn('employee_uuid', SyncType.uuid);
const _notes = SyncColumn('notes', SyncType.text, nullable: true, maxLength: 10000);

/// `created_at`/`calculated_at` — строки как есть (местное время из старой
/// базы, без пояса).
const _stamp = [SyncColumn('created_at', SyncType.text, maxLength: 32)];

/// Синхронизируемые таблицы в порядке записи: сначала то, на что ссылаются
/// (сотрудники), потом ссылающиеся.
const syncTables = <SyncTable>[
  SyncTable('company_settings', [
    _legacyId,
    SyncColumn('company_name', SyncType.text, maxLength: 255),
    SyncColumn('director_name', SyncType.text, nullable: true, maxLength: 255),
    SyncColumn('inn', SyncType.text, nullable: true, maxLength: 32),
    SyncColumn('ogrn', SyncType.text, nullable: true, maxLength: 32),
    SyncColumn('bank_account', SyncType.text, nullable: true, maxLength: 64),
    SyncColumn('bank_name', SyncType.text, nullable: true, maxLength: 255),
    SyncColumn('legal_address', SyncType.text, nullable: true, maxLength: 500),
    SyncColumn('phone', SyncType.text, nullable: true, maxLength: 64),
    SyncColumn('default_work_day_hours', SyncType.real),
    SyncColumn('overtime_multiplier', SyncType.real),
    SyncColumn('night_shift_multiplier', SyncType.real),
  ]),
  SyncTable('employees', [
    _legacyId,
    SyncColumn('full_name', SyncType.text, maxLength: 255),
    SyncColumn('position', SyncType.text, maxLength: 255),
    SyncColumn('hire_date', SyncType.date),
    SyncColumn('dismissal_date', SyncType.date, nullable: true),
    SyncColumn('base_rate', SyncType.real),
    SyncColumn('field_rate', SyncType.real),
  ]),
  SyncTable('employee_rates', [
    _legacyId,
    _employee,
    SyncColumn('base_rate', SyncType.real),
    SyncColumn('field_rate', SyncType.real),
    SyncColumn('start_date', SyncType.date),
    SyncColumn('end_date', SyncType.date, nullable: true),
  ]),
  SyncTable('timesheet', [
    _legacyId,
    _employee,
    SyncColumn('date', SyncType.date),
    SyncColumn('day_type', SyncType.text,
        allowed: {'work', 'sick', 'vacation', 'dayoff'}),
    SyncColumn('days', SyncType.real, min: 0, max: 1),
    // Место бывает и у нерабочих дней — проверяется только значение.
    SyncColumn('work_place', SyncType.text,
        nullable: true, allowed: {'base', 'field'}),
    _notes,
    ..._stamp,
  ]),
  SyncTable('payments', [
    _legacyId,
    _employee,
    SyncColumn('payment_date', SyncType.date),
    SyncColumn('amount', SyncType.real),
    SyncColumn('payment_type', SyncType.text, maxLength: 32),
    SyncColumn('period_start', SyncType.date, nullable: true),
    SyncColumn('period_end', SyncType.date, nullable: true),
    SyncColumn('payment_method', SyncType.text, nullable: true, maxLength: 32),
    SyncColumn('document_number', SyncType.text, nullable: true, maxLength: 64),
    _notes,
    ..._stamp,
  ]),
  SyncTable('sick_leave', [
    _legacyId,
    _employee,
    SyncColumn('start_date', SyncType.date),
    SyncColumn('end_date', SyncType.date),
    SyncColumn('document_number', SyncType.text, nullable: true, maxLength: 64),
    SyncColumn('days_count', SyncType.integer, min: 0, max: 10000),
    SyncColumn('paid_by_employer', SyncType.real, nullable: true),
    SyncColumn('paid_by_fss', SyncType.real, nullable: true),
    _notes,
  ]),
  SyncTable('vacation', [
    _legacyId,
    _employee,
    SyncColumn('start_date', SyncType.date),
    SyncColumn('end_date', SyncType.date),
    SyncColumn('vacation_type', SyncType.text, maxLength: 32),
    SyncColumn('days_count', SyncType.integer, min: 0, max: 10000),
    SyncColumn('is_approved', SyncType.boolean),
    _notes,
  ]),
  SyncTable('payroll_results', [
    _legacyId,
    _employee,
    SyncColumn('year', SyncType.integer, min: 1900, max: 2200),
    SyncColumn('month', SyncType.integer, min: 1, max: 12),
    SyncColumn('base_days', SyncType.real),
    SyncColumn('field_days', SyncType.real),
    SyncColumn('sick_days', SyncType.real),
    SyncColumn('vacation_days', SyncType.real),
    SyncColumn('total_salary', SyncType.real),
    SyncColumn('base_rate_used', SyncType.real, nullable: true),
    SyncColumn('field_rate_used', SyncType.real, nullable: true),
    SyncColumn('calculated_at', SyncType.text, maxLength: 32),
    SyncColumn('status', SyncType.text,
        allowed: {'calculated', 'verified', 'discrepancy'}),
    SyncColumn('skipped_work_days', SyncType.integer, min: 0, max: 31),
  ]),
];

/// Таблица по имени или null (имя пришло от клиента — не доверяем).
SyncTable? syncTableByName(String name) {
  for (final t in syncTables) {
    if (t.name == name) return t;
  }
  return null;
}

/// Место таблицы в порядке записи (сначала сотрудники).
int syncTableOrder(String name) =>
    syncTables.indexWhere((t) => t.name == name);
