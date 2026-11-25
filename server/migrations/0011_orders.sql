-- Заказы (этап 11.4, схема drift 7, packages/local_db/lib/src/tables/
-- sales_tables.dart): выдачи (день забоя / выдачи), заказы и строки.
-- В строке «заказано» и «фактически» — раздельно; часть набора —
-- parent_line_uuid (без внешнего ключа: в MySQL ключи не отложенные, а
-- часть может прийти в пачке раньше своего набора; целостность — по
-- order_uuid). Сверку с клиентом делает test/schema_test.dart.
--
-- Только добавляет таблицы; существующие данные не меняются.

CREATE TABLE sale_batches (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  day DATE NOT NULL,
  day_to DATE NULL,
  title VARCHAR(255) NULL,
  notes TEXT NULL,
  not_deleted TINYINT AS (IF(deleted = 0, 1, NULL)) VIRTUAL,
  PRIMARY KEY (uuid),
  UNIQUE KEY idx_sale_batches_day (day, not_deleted),
  CHECK (deleted IN (0, 1))
);

CREATE TABLE sale_orders (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  batch_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  customer_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  number INT NOT NULL,
  kind VARCHAR(16) NOT NULL DEFAULT 'sale',
  delivery VARCHAR(16) NOT NULL DEFAULT 'pickup',
  address TEXT NULL,
  comment TEXT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'new',
  created_by VARCHAR(64) NULL,
  PRIMARY KEY (uuid),
  KEY idx_sale_orders_batch (batch_uuid),
  KEY idx_sale_orders_customer (customer_uuid),
  CONSTRAINT fk_sale_orders_batch
    FOREIGN KEY (batch_uuid) REFERENCES sale_batches (uuid),
  CONSTRAINT fk_sale_orders_customer
    FOREIGN KEY (customer_uuid) REFERENCES customers (uuid),
  CHECK (deleted IN (0, 1)),
  CHECK (number >= 1),
  CHECK (kind IN ('sale', 'free', 'own')),
  CHECK (delivery IN ('pickup', 'delivery')),
  CHECK (status IN ('new', 'assembled', 'issued', 'cancelled'))
);

CREATE TABLE sale_order_lines (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  order_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  parent_line_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  product_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  ordered_qty DOUBLE NULL,
  ordered_unit VARCHAR(8) NULL,
  ordered_text TEXT NULL,
  weight DOUBLE NULL,
  pieces INT NULL,
  pricing VARCHAR(16) NOT NULL DEFAULT 'list',
  price BIGINT NULL,
  fixed_amount BIGINT NULL,
  state VARCHAR(16) NOT NULL DEFAULT 'open',
  note TEXT NULL,
  added TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (uuid),
  KEY idx_sale_order_lines_order (order_uuid),
  CONSTRAINT fk_sale_order_lines_order
    FOREIGN KEY (order_uuid) REFERENCES sale_orders (uuid),
  CONSTRAINT fk_sale_order_lines_product
    FOREIGN KEY (product_uuid) REFERENCES products (uuid),
  CHECK (deleted IN (0, 1)),
  CHECK (added IN (0, 1)),
  CHECK (ordered_unit IS NULL OR ordered_unit IN ('kg', 'pcs', 'rub')),
  CHECK (pricing IN ('list', 'parts', 'manual', 'fixed')),
  CHECK (state IN ('open', 'assembled', 'missing'))
);
