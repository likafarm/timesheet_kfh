-- Платёжный календарь и БДДС (схема drift 5, packages/local_db/lib/src/
-- tables/finance_tables.dart, FinPlans и FinBudget): плановые поступления
-- и платежи, разово или с повтором (оплата плана — обычная операция
-- fin_operations со ссылкой source_ref = 'plan:<uuid плана>:<день>'), и
-- план по статьям и месяцам.
-- Сверку с клиентом делает test/schema_test.dart.
--
-- Только добавляет таблицы; существующие данные не меняются.

CREATE TABLE fin_plans (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  type VARCHAR(16) NOT NULL,
  amount BIGINT NOT NULL,
  start_date DATE NOT NULL,
  recurrence VARCHAR(16) NOT NULL DEFAULT 'none',
  until_date DATE NULL,
  account_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  category_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  counterparty_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  description TEXT NULL,
  skipped TEXT NULL,
  closed TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (uuid),
  KEY idx_fin_plans_start (start_date),
  CONSTRAINT fk_fin_plans_account
    FOREIGN KEY (account_uuid) REFERENCES fin_accounts (uuid),
  CONSTRAINT fk_fin_plans_category
    FOREIGN KEY (category_uuid) REFERENCES fin_categories (uuid),
  CONSTRAINT fk_fin_plans_counterparty
    FOREIGN KEY (counterparty_uuid) REFERENCES counterparties (uuid),
  CHECK (deleted IN (0, 1)),
  CHECK (closed IN (0, 1)),
  CHECK (amount > 0),
  CHECK (type IN ('income', 'expense')),
  CHECK (recurrence IN ('none', 'monthly', 'quarterly', 'yearly'))
);

CREATE TABLE fin_budget (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  year INT NOT NULL,
  month INT NOT NULL,
  category_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  amount BIGINT NOT NULL,
  not_deleted TINYINT AS (IF(deleted = 0, 1, NULL)) VIRTUAL,
  PRIMARY KEY (uuid),
  UNIQUE KEY idx_fin_budget_key (year, month, category_uuid, not_deleted),
  CONSTRAINT fk_fin_budget_category
    FOREIGN KEY (category_uuid) REFERENCES fin_categories (uuid),
  CHECK (deleted IN (0, 1)),
  CHECK (month BETWEEN 1 AND 12),
  CHECK (amount >= 0)
);
