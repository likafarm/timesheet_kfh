-- Покупатели (этап 11.3, схема drift 7, packages/local_db/lib/src/tables/
-- sales_tables.dart, Customers): отдельно от контрагентов финансов —
-- программы до 1.22 не знают этих полей. counterparty_uuid — контрагент,
-- на которого пишутся оплаты (11.6). Сверку с клиентом делает
-- test/schema_test.dart.
--
-- Только добавляет таблицу; существующие данные не меняются.

CREATE TABLE customers (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  name VARCHAR(255) NOT NULL,
  phone VARCHAR(64) NULL,
  address TEXT NULL,
  channel VARCHAR(16) NULL,
  contact VARCHAR(255) NULL,
  notes TEXT NULL,
  counterparty_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  PRIMARY KEY (uuid),
  KEY idx_customers_name (name),
  CONSTRAINT fk_customers_counterparty
    FOREIGN KEY (counterparty_uuid) REFERENCES counterparties (uuid),
  CHECK (deleted IN (0, 1)),
  CHECK (channel IS NULL OR channel IN
    ('telegram', 'whatsapp', 'max', 'vk', 'sms', 'phone', 'other'))
);
