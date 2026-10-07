-- Финансы (этап 8): таблицы повторяют клиентские (схема drift 2,
-- packages/local_db/lib/src/tables/finance_tables.dart); сверку делает
-- test/schema_test.dart. Правила те же, что в 0001: дни — DATE, суммы —
-- копейки BIGINT, уникальность среди неудалённых строк — через not_deleted,
-- внешние ключи обычные (сервер пишет пачку в порядке таблиц), коды
-- перечислений — CHECK.
--
-- Только добавляет таблицы; существующие не меняются.

CREATE TABLE fin_directions (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  name VARCHAR(255) NOT NULL,
  overhead TINYINT(1) NOT NULL DEFAULT 0,
  sort_order INT NOT NULL DEFAULT 0,
  not_deleted TINYINT AS (IF(deleted = 0, 1, NULL)) VIRTUAL,
  PRIMARY KEY (uuid),
  UNIQUE KEY idx_fin_directions_name (name, not_deleted),
  CHECK (deleted IN (0, 1)),
  CHECK (overhead IN (0, 1))
);

CREATE TABLE fin_allocation_keys (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  name VARCHAR(255) NOT NULL,
  not_deleted TINYINT AS (IF(deleted = 0, 1, NULL)) VIRTUAL,
  PRIMARY KEY (uuid),
  UNIQUE KEY idx_fin_allocation_keys_name (name, not_deleted),
  CHECK (deleted IN (0, 1))
);

CREATE TABLE fin_allocation_periods (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  key_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  valid_from DATE NOT NULL,
  -- {"uuid направления": процент}; проверяет сервер (kfh_domain).
  shares VARCHAR(2000) NOT NULL,
  not_deleted TINYINT AS (IF(deleted = 0, 1, NULL)) VIRTUAL,
  PRIMARY KEY (uuid),
  UNIQUE KEY idx_fin_allocation_periods_unique (key_uuid, valid_from, not_deleted),
  CONSTRAINT fk_fin_allocation_periods_key
    FOREIGN KEY (key_uuid) REFERENCES fin_allocation_keys (uuid),
  CHECK (deleted IN (0, 1))
);

CREATE TABLE fin_accounts (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  name VARCHAR(255) NOT NULL,
  kind VARCHAR(16) NOT NULL,
  opening_balance BIGINT NOT NULL DEFAULT 0,
  opening_date DATE NULL,
  employee_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  closed TINYINT(1) NOT NULL DEFAULT 0,
  sort_order INT NOT NULL DEFAULT 0,
  not_deleted TINYINT AS (IF(deleted = 0, 1, NULL)) VIRTUAL,
  PRIMARY KEY (uuid),
  UNIQUE KEY idx_fin_accounts_name (name, not_deleted),
  CONSTRAINT fk_fin_accounts_employee
    FOREIGN KEY (employee_uuid) REFERENCES employees (uuid),
  CHECK (deleted IN (0, 1)),
  CHECK (closed IN (0, 1)),
  CHECK (kind IN ('cash', 'bank', 'card', 'credit_card', 'accountable'))
);

CREATE TABLE fin_assets (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  name VARCHAR(255) NOT NULL,
  kind VARCHAR(16) NOT NULL,
  year INT NULL,
  quantity INT NOT NULL DEFAULT 1,
  reference_value BIGINT NULL,
  valued_on DATE NULL,
  direction_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  allocation_key_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  cadastral_number VARCHAR(64) NULL,
  area_ha DOUBLE NULL,
  cadastral_value BIGINT NULL,
  disposed_on DATE NULL,
  disposal_reason VARCHAR(255) NULL,
  notes TEXT NULL,
  PRIMARY KEY (uuid),
  CONSTRAINT fk_fin_assets_direction
    FOREIGN KEY (direction_uuid) REFERENCES fin_directions (uuid),
  CONSTRAINT fk_fin_assets_key
    FOREIGN KEY (allocation_key_uuid) REFERENCES fin_allocation_keys (uuid),
  CHECK (deleted IN (0, 1)),
  CHECK (kind IN ('building', 'machinery', 'equipment', 'vehicle', 'land',
    'other'))
);

CREATE TABLE fin_categories (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  type VARCHAR(16) NOT NULL,
  group_name VARCHAR(255) NOT NULL,
  name VARCHAR(255) NOT NULL,
  direction_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  allocation_key_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  kind VARCHAR(16) NOT NULL DEFAULT 'current',
  in_tax_book TINYINT(1) NOT NULL DEFAULT 1,
  hidden TINYINT(1) NOT NULL DEFAULT 0,
  sort_order INT NOT NULL DEFAULT 0,
  not_deleted TINYINT AS (IF(deleted = 0, 1, NULL)) VIRTUAL,
  PRIMARY KEY (uuid),
  UNIQUE KEY idx_fin_categories_name (type, name, not_deleted),
  CONSTRAINT fk_fin_categories_direction
    FOREIGN KEY (direction_uuid) REFERENCES fin_directions (uuid),
  CONSTRAINT fk_fin_categories_key
    FOREIGN KEY (allocation_key_uuid) REFERENCES fin_allocation_keys (uuid),
  CHECK (deleted IN (0, 1)),
  CHECK (in_tax_book IN (0, 1)),
  CHECK (hidden IN (0, 1)),
  CHECK (type IN ('income', 'expense')),
  CHECK (kind IN ('current', 'capex', 'refund'))
);

CREATE TABLE counterparties (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  name VARCHAR(255) NOT NULL,
  kind VARCHAR(16) NOT NULL DEFAULT 'other',
  inn VARCHAR(32) NULL,
  phone VARCHAR(64) NULL,
  employee_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  notes TEXT NULL,
  not_deleted TINYINT AS (IF(deleted = 0, 1, NULL)) VIRTUAL,
  PRIMARY KEY (uuid),
  UNIQUE KEY idx_counterparties_name (name, not_deleted),
  CONSTRAINT fk_counterparties_employee
    FOREIGN KEY (employee_uuid) REFERENCES employees (uuid),
  CHECK (deleted IN (0, 1)),
  CHECK (kind IN ('buyer', 'supplier', 'person', 'bank', 'other'))
);

CREATE TABLE fin_debts (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  counterparty_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  kind VARCHAR(16) NOT NULL,
  opening_balance BIGINT NOT NULL DEFAULT 0,
  opening_date DATE NULL,
  closed TINYINT(1) NOT NULL DEFAULT 0,
  notes TEXT NULL,
  PRIMARY KEY (uuid),
  CONSTRAINT fk_fin_debts_counterparty
    FOREIGN KEY (counterparty_uuid) REFERENCES counterparties (uuid),
  CHECK (deleted IN (0, 1)),
  CHECK (closed IN (0, 1)),
  CHECK (kind IN ('received', 'given'))
);

CREATE TABLE fin_operations (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  date DATE NOT NULL,
  type VARCHAR(16) NOT NULL,
  amount BIGINT NOT NULL,
  account_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  to_account_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  category_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  direction_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  allocation_key_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  asset_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  season INT NULL,
  counterparty_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  employee_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  debt_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  debt_move VARCHAR(16) NULL,
  description VARCHAR(500) NULL,
  quantity DOUBLE NULL,
  unit VARCHAR(32) NULL,
  tag VARCHAR(64) NULL,
  notes TEXT NULL,
  source VARCHAR(16) NOT NULL DEFAULT 'manual',
  source_ref VARCHAR(255) NULL,
  created_by VARCHAR(64) NULL,
  created_at VARCHAR(32) NOT NULL,
  PRIMARY KEY (uuid),
  KEY idx_fin_operations_date (date),
  KEY idx_fin_operations_account (account_uuid, date),
  KEY idx_fin_operations_category (category_uuid),
  CONSTRAINT fk_fin_operations_account
    FOREIGN KEY (account_uuid) REFERENCES fin_accounts (uuid),
  CONSTRAINT fk_fin_operations_to_account
    FOREIGN KEY (to_account_uuid) REFERENCES fin_accounts (uuid),
  CONSTRAINT fk_fin_operations_category
    FOREIGN KEY (category_uuid) REFERENCES fin_categories (uuid),
  CONSTRAINT fk_fin_operations_direction
    FOREIGN KEY (direction_uuid) REFERENCES fin_directions (uuid),
  CONSTRAINT fk_fin_operations_key
    FOREIGN KEY (allocation_key_uuid) REFERENCES fin_allocation_keys (uuid),
  CONSTRAINT fk_fin_operations_asset
    FOREIGN KEY (asset_uuid) REFERENCES fin_assets (uuid),
  CONSTRAINT fk_fin_operations_counterparty
    FOREIGN KEY (counterparty_uuid) REFERENCES counterparties (uuid),
  CONSTRAINT fk_fin_operations_employee
    FOREIGN KEY (employee_uuid) REFERENCES employees (uuid),
  CONSTRAINT fk_fin_operations_debt
    FOREIGN KEY (debt_uuid) REFERENCES fin_debts (uuid),
  CHECK (deleted IN (0, 1)),
  CHECK (amount > 0),
  CHECK (type IN ('income', 'expense', 'transfer', 'debt')),
  CHECK (debt_move IS NULL OR debt_move IN ('take', 'repay', 'lend',
    'collect')),
  CHECK (source IN ('manual', 'import', 'payroll', 'bank', 'evotor'))
);

CREATE TABLE fin_payroll_mapping (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  kind VARCHAR(32) NOT NULL,
  value VARCHAR(255) NOT NULL DEFAULT '',
  -- uuid кошелька или статьи (по виду) — без внешнего ключа.
  target_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  not_deleted TINYINT AS (IF(deleted = 0, 1, NULL)) VIRTUAL,
  PRIMARY KEY (uuid),
  UNIQUE KEY idx_fin_payroll_mapping_unique (kind, value, not_deleted),
  CHECK (deleted IN (0, 1)),
  CHECK (kind IN ('method', 'position', 'default_account',
    'default_category'))
);
