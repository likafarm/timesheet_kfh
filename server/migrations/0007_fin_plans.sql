-- Платёжный календарь (схема drift 5, packages/local_db/lib/src/tables/
-- finance_tables.dart, FinPlans): плановые поступления и платежи, разово
-- или с повтором. Оплата плана — обычная операция fin_operations со
-- ссылкой source_ref = 'plan:<uuid плана>:<день>'.
-- Сверку с клиентом делает test/schema_test.dart.
--
-- Только добавляет таблицу; существующие данные не меняются.

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
