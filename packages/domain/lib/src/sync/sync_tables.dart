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

  /// Уникальный ключ среди неудалённых строк (кроме uuid); пусто — нет.
  final List<String> unique;

  const SyncTable(this.name, this.columns, {this.unique = const []});

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
const _notes = SyncColumn(
  'notes',
  SyncType.text,
  nullable: true,
  maxLength: 10000,
);

/// Суммы финансов — копейки (до 10 трлн ₽ — с запасом и в JS).
const _maxKopecks = 1000000000000000;
const _sortOrder = SyncColumn(
  'sort_order',
  SyncType.integer,
  min: -1000000,
  max: 1000000,
);

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
  SyncTable(
    'timesheet',
    unique: ['employee_uuid', 'date'],
    [
      _legacyId,
      _employee,
      SyncColumn('date', SyncType.date),
      SyncColumn(
        'day_type',
        SyncType.text,
        allowed: {'work', 'sick', 'vacation', 'dayoff'},
      ),
      SyncColumn('days', SyncType.real, min: 0, max: 1),
      // Место бывает и у нерабочих дней — проверяется только значение.
      SyncColumn(
        'work_place',
        SyncType.text,
        nullable: true,
        allowed: {'base', 'field'},
      ),
      _notes,
      ..._stamp,
    ],
  ),
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
  SyncTable(
    'payroll_results',
    unique: ['employee_uuid', 'year', 'month'],
    [
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
      SyncColumn(
        'status',
        SyncType.text,
        allowed: {'calculated', 'verified', 'discrepancy'},
      ),
      SyncColumn('skipped_work_days', SyncType.integer, min: 0, max: 31),
    ],
  ),
  // --- Финансы (этап 8, схема 2) ------------------------------------------
  SyncTable(
    'fin_directions',
    unique: ['name'],
    [
      _legacyId,
      SyncColumn('name', SyncType.text, maxLength: 255),
      SyncColumn('overhead', SyncType.boolean),
      _sortOrder,
    ],
  ),
  SyncTable(
    'fin_allocation_keys',
    unique: ['name'],
    [_legacyId, SyncColumn('name', SyncType.text, maxLength: 255)],
  ),
  SyncTable(
    'fin_allocation_periods',
    unique: ['key_uuid', 'valid_from'],
    [
      _legacyId,
      SyncColumn('key_uuid', SyncType.uuid),
      SyncColumn('valid_from', SyncType.date),
      SyncColumn('shares', SyncType.text, maxLength: 2000),
    ],
  ),
  SyncTable(
    'fin_accounts',
    unique: ['name'],
    [
      _legacyId,
      SyncColumn('name', SyncType.text, maxLength: 255),
      SyncColumn(
        'kind',
        SyncType.text,
        allowed: {'cash', 'bank', 'card', 'credit_card', 'accountable'},
      ),
      SyncColumn(
        'opening_balance',
        SyncType.integer,
        min: -_maxKopecks,
        max: _maxKopecks,
      ),
      SyncColumn('opening_date', SyncType.date, nullable: true),
      SyncColumn('employee_uuid', SyncType.uuid, nullable: true),
      SyncColumn('closed', SyncType.boolean),
      _sortOrder,
    ],
  ),
  SyncTable('fin_assets', [
    _legacyId,
    SyncColumn('name', SyncType.text, maxLength: 255),
    SyncColumn(
      'kind',
      SyncType.text,
      allowed: {
        'building',
        'machinery',
        'equipment',
        'vehicle',
        'land',
        'other',
      },
    ),
    SyncColumn('year', SyncType.integer, nullable: true, min: 1900, max: 2200),
    SyncColumn('quantity', SyncType.integer, min: 0, max: 1000000),
    SyncColumn(
      'reference_value',
      SyncType.integer,
      nullable: true,
      min: 0,
      max: _maxKopecks,
    ),
    SyncColumn('valued_on', SyncType.date, nullable: true),
    SyncColumn('direction_uuid', SyncType.uuid, nullable: true),
    SyncColumn('allocation_key_uuid', SyncType.uuid, nullable: true),
    SyncColumn(
      'cadastral_number',
      SyncType.text,
      nullable: true,
      maxLength: 64,
    ),
    SyncColumn('area_ha', SyncType.real, nullable: true),
    SyncColumn(
      'cadastral_value',
      SyncType.integer,
      nullable: true,
      min: 0,
      max: _maxKopecks,
    ),
    SyncColumn('disposed_on', SyncType.date, nullable: true),
    SyncColumn(
      'disposal_reason',
      SyncType.text,
      nullable: true,
      maxLength: 255,
    ),
    _notes,
  ]),
  SyncTable(
    'fin_categories',
    unique: ['type', 'name'],
    [
      _legacyId,
      SyncColumn('type', SyncType.text, allowed: {'income', 'expense'}),
      SyncColumn('group_name', SyncType.text, maxLength: 255),
      SyncColumn('name', SyncType.text, maxLength: 255),
      SyncColumn('direction_uuid', SyncType.uuid, nullable: true),
      SyncColumn('allocation_key_uuid', SyncType.uuid, nullable: true),
      SyncColumn(
        'kind',
        SyncType.text,
        allowed: {'current', 'capex', 'refund'},
      ),
      SyncColumn('in_tax_book', SyncType.boolean),
      SyncColumn('hidden', SyncType.boolean),
      _sortOrder,
    ],
  ),
  SyncTable(
    'counterparties',
    unique: ['name'],
    [
      _legacyId,
      SyncColumn('name', SyncType.text, maxLength: 255),
      SyncColumn(
        'kind',
        SyncType.text,
        allowed: {'buyer', 'supplier', 'person', 'bank', 'other'},
      ),
      SyncColumn('inn', SyncType.text, nullable: true, maxLength: 32),
      SyncColumn('phone', SyncType.text, nullable: true, maxLength: 64),
      SyncColumn('employee_uuid', SyncType.uuid, nullable: true),
      _notes,
    ],
  ),
  SyncTable('fin_debts', [
    _legacyId,
    SyncColumn('counterparty_uuid', SyncType.uuid),
    SyncColumn('kind', SyncType.text, allowed: {'received', 'given'}),
    SyncColumn(
      'opening_balance',
      SyncType.integer,
      min: -_maxKopecks,
      max: _maxKopecks,
    ),
    SyncColumn('opening_date', SyncType.date, nullable: true),
    SyncColumn('closed', SyncType.boolean),
    _notes,
  ]),
  SyncTable('fin_operations', [
    _legacyId,
    SyncColumn('date', SyncType.date),
    SyncColumn(
      'type',
      SyncType.text,
      allowed: {'income', 'expense', 'transfer', 'debt'},
    ),
    SyncColumn('amount', SyncType.integer, min: 1, max: _maxKopecks),
    SyncColumn('account_uuid', SyncType.uuid),
    SyncColumn('to_account_uuid', SyncType.uuid, nullable: true),
    SyncColumn('category_uuid', SyncType.uuid, nullable: true),
    SyncColumn('direction_uuid', SyncType.uuid, nullable: true),
    SyncColumn('allocation_key_uuid', SyncType.uuid, nullable: true),
    SyncColumn('asset_uuid', SyncType.uuid, nullable: true),
    SyncColumn(
      'season',
      SyncType.integer,
      nullable: true,
      min: 2000,
      max: 2100,
    ),
    SyncColumn('counterparty_uuid', SyncType.uuid, nullable: true),
    SyncColumn('employee_uuid', SyncType.uuid, nullable: true),
    SyncColumn('debt_uuid', SyncType.uuid, nullable: true),
    SyncColumn(
      'debt_move',
      SyncType.text,
      nullable: true,
      allowed: {'take', 'repay', 'lend', 'collect'},
    ),
    SyncColumn('description', SyncType.text, nullable: true, maxLength: 500),
    SyncColumn('quantity', SyncType.real, nullable: true),
    SyncColumn('unit', SyncType.text, nullable: true, maxLength: 32),
    SyncColumn('tag', SyncType.text, nullable: true, maxLength: 64),
    _notes,
    SyncColumn(
      'source',
      SyncType.text,
      allowed: {'manual', 'import', 'payroll', 'bank', 'evotor'},
    ),
    SyncColumn('source_ref', SyncType.text, nullable: true, maxLength: 255),
    SyncColumn('created_by', SyncType.text, nullable: true, maxLength: 64),
    ..._stamp,
  ]),
  SyncTable(
    'fin_payroll_mapping',
    unique: ['kind', 'value'],
    [
      _legacyId,
      SyncColumn(
        'kind',
        SyncType.text,
        allowed: {'method', 'position', 'default_account', 'default_category'},
      ),
      SyncColumn('value', SyncType.text, maxLength: 255),
      SyncColumn('target_uuid', SyncType.uuid),
    ],
  ),
];

/// Таблицы до финансов (схема 1). Программы до 1.18 спрашивают изменения
/// без списка таблиц и не знают остальных: сервер отдаёт им только эти.
const legacySyncTableNames = <String>{
  'company_settings',
  'employees',
  'employee_rates',
  'timesheet',
  'payments',
  'sick_leave',
  'vacation',
  'payroll_results',
};

/// Таблица по имени или null (имя пришло от клиента — не доверяем).
SyncTable? syncTableByName(String name) {
  for (final t in syncTables) {
    if (t.name == name) return t;
  }
  return null;
}

/// Место таблицы в порядке записи (сначала сотрудники).
int syncTableOrder(String name) => syncTables.indexWhere((t) => t.name == name);
