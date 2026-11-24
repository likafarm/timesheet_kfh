-- Прайс-лист (этап 11.1, схема drift 6, packages/local_db/lib/src/tables/
-- sales_tables.dart): группы, товары и цены с даты начала. Редакция прайса —
-- все цены, начавшиеся в один день; отдельной таблицы у неё нет.
-- Сверку с клиентом делает test/schema_test.dart.
--
-- Только добавляет таблицы; существующие данные не меняются.

CREATE TABLE product_groups (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  name VARCHAR(255) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  not_deleted TINYINT AS (IF(deleted = 0, 1, NULL)) VIRTUAL,
  PRIMARY KEY (uuid),
  UNIQUE KEY idx_product_groups_name (name, not_deleted),
  CHECK (deleted IN (0, 1))
);

CREATE TABLE products (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  group_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  name VARCHAR(255) NOT NULL,
  unit VARCHAR(16) NOT NULL DEFAULT 'kg',
  sort_order INT NOT NULL DEFAULT 0,
  hidden TINYINT(1) NOT NULL DEFAULT 0,
  notes TEXT NULL,
  not_deleted TINYINT AS (IF(deleted = 0, 1, NULL)) VIRTUAL,
  PRIMARY KEY (uuid),
  UNIQUE KEY idx_products_name (name, not_deleted),
  CONSTRAINT fk_products_group
    FOREIGN KEY (group_uuid) REFERENCES product_groups (uuid),
  CHECK (deleted IN (0, 1)),
  CHECK (hidden IN (0, 1)),
  CHECK (unit IN ('kg', 'pcs', 'pack', 'can'))
);

CREATE TABLE product_prices (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  product_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  valid_from DATE NOT NULL,
  price BIGINT NOT NULL,
  not_deleted TINYINT AS (IF(deleted = 0, 1, NULL)) VIRTUAL,
  PRIMARY KEY (uuid),
  UNIQUE KEY idx_product_prices_key (product_uuid, valid_from, not_deleted),
  CONSTRAINT fk_product_prices_product
    FOREIGN KEY (product_uuid) REFERENCES products (uuid),
  CHECK (deleted IN (0, 1)),
  CHECK (price > 0)
);
