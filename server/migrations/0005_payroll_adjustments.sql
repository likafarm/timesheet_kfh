-- Корректировки начисления за месяц (схема drift 3,
-- packages/local_db/lib/src/tables/tables.dart, PayrollAdjustments):
-- доплата (плюс) или удержание (минус) в рублях, несколько на месяц можно.
-- Сверку с клиентом делает test/schema_test.dart.
--
-- Только добавляет таблицу; существующие не меняются.

CREATE TABLE payroll_adjustments (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  employee_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  year INT NOT NULL,
  month INT NOT NULL,
  amount DOUBLE NOT NULL,
  notes TEXT NULL,
  PRIMARY KEY (uuid),
  KEY idx_payroll_adjustments_month (year, month),
  KEY idx_payroll_adjustments_employee (employee_uuid),
  CONSTRAINT fk_payroll_adjustments_employee
    FOREIGN KEY (employee_uuid) REFERENCES employees (uuid),
  CHECK (deleted IN (0, 1)),
  CHECK (month BETWEEN 1 AND 12)
);
