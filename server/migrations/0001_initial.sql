-- Схема v2 на сервере (MySQL 8.4). Бизнес-таблицы повторяют локальную
-- схему клиента (packages/local_db/lib/src/tables/tables.dart), сверку
-- делает test/schema_test.dart. Отличия от клиента:
--
-- * нет remote_updated_at — это поле только клиента;
-- * даты дней — тип DATE (в клиенте строки гггг-мм-дд);
-- * created_at/calculated_at — строки как есть (перенесены из старой базы
--   в местном времени без пояса);
-- * уникальность среди неудалённых строк: в MySQL нет частичных индексов,
--   поэтому служебный столбец not_deleted = 1 или NULL, а NULL в
--   уникальном индексе не конфликтует;
-- * внешние ключи обычные (отложенных в MySQL нет): сервер пишет пачку
--   синхронизации в порядке таблиц — сначала сотрудники.
--
-- uuid — CHAR(36) ascii_bin: строка как у клиента, сравнение побайтное.
-- updated_at — DATETIME(6), UTC: микросекунды клиента сохраняются, иначе
-- сравнение last-write-wins сломается на округлении.
--
-- DDL в MySQL не откатывается транзакцией: перед миграцией — резервная
-- копия (deploy.sh), при ошибке — восстановление из неё.

CREATE TABLE company_settings (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  company_name VARCHAR(255) NOT NULL DEFAULT 'КФХ',
  director_name VARCHAR(255) NULL,
  inn VARCHAR(32) NULL,
  ogrn VARCHAR(32) NULL,
  bank_account VARCHAR(64) NULL,
  bank_name VARCHAR(255) NULL,
  legal_address VARCHAR(500) NULL,
  phone VARCHAR(64) NULL,
  default_work_day_hours DOUBLE NOT NULL DEFAULT 8.0,
  overtime_multiplier DOUBLE NOT NULL DEFAULT 1.5,
  night_shift_multiplier DOUBLE NOT NULL DEFAULT 1.2,
  PRIMARY KEY (uuid),
  CHECK (deleted IN (0, 1))
);

CREATE TABLE employees (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  full_name VARCHAR(255) NOT NULL,
  position VARCHAR(255) NOT NULL,
  hire_date DATE NOT NULL,
  dismissal_date DATE NULL,
  base_rate DOUBLE NOT NULL DEFAULT 0.0,
  field_rate DOUBLE NOT NULL DEFAULT 0.0,
  PRIMARY KEY (uuid),
  KEY idx_employees_full_name (full_name),
  CHECK (deleted IN (0, 1))
);

CREATE TABLE employee_rates (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  employee_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  base_rate DOUBLE NOT NULL,
  field_rate DOUBLE NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NULL,
  PRIMARY KEY (uuid),
  KEY idx_employee_rates_employee (employee_uuid, start_date),
  CONSTRAINT fk_employee_rates_employee
    FOREIGN KEY (employee_uuid) REFERENCES employees (uuid),
  CHECK (deleted IN (0, 1))
);

CREATE TABLE timesheet (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  employee_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  date DATE NOT NULL,
  day_type VARCHAR(16) NOT NULL DEFAULT 'work',
  days DOUBLE NOT NULL DEFAULT 0.0,
  -- Место бывает и у нерабочих дней (так в реальных данных), поэтому
  -- проверяется только значение.
  work_place VARCHAR(16) NULL,
  notes TEXT NULL,
  created_at VARCHAR(32) NOT NULL,
  not_deleted TINYINT AS (IF(deleted = 0, 1, NULL)) VIRTUAL,
  PRIMARY KEY (uuid),
  UNIQUE KEY idx_timesheet_unique (employee_uuid, date, not_deleted),
  KEY idx_timesheet_date (date),
  CONSTRAINT fk_timesheet_employee
    FOREIGN KEY (employee_uuid) REFERENCES employees (uuid),
  CHECK (deleted IN (0, 1)),
  CHECK (day_type IN ('work', 'sick', 'vacation', 'dayoff')),
  CHECK (work_place IS NULL OR work_place IN ('base', 'field')),
  CHECK (days >= 0 AND days <= 1)
);

CREATE TABLE payments (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  employee_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  payment_date DATE NOT NULL,
  amount DOUBLE NOT NULL,
  payment_type VARCHAR(32) NOT NULL DEFAULT 'salary',
  period_start DATE NULL,
  period_end DATE NULL,
  payment_method VARCHAR(32) NULL,
  document_number VARCHAR(64) NULL,
  notes TEXT NULL,
  created_at VARCHAR(32) NOT NULL,
  PRIMARY KEY (uuid),
  KEY idx_payments_employee_date (employee_uuid, payment_date),
  KEY idx_payments_date (payment_date),
  CONSTRAINT fk_payments_employee
    FOREIGN KEY (employee_uuid) REFERENCES employees (uuid),
  CHECK (deleted IN (0, 1))
);

CREATE TABLE sick_leave (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  employee_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  document_number VARCHAR(64) NULL,
  days_count INT NOT NULL,
  paid_by_employer DOUBLE NULL,
  paid_by_fss DOUBLE NULL,
  notes TEXT NULL,
  PRIMARY KEY (uuid),
  KEY idx_sick_leave_employee (employee_uuid),
  CONSTRAINT fk_sick_leave_employee
    FOREIGN KEY (employee_uuid) REFERENCES employees (uuid),
  CHECK (deleted IN (0, 1))
);

CREATE TABLE vacation (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  employee_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  vacation_type VARCHAR(32) NOT NULL DEFAULT 'annual',
  days_count INT NOT NULL,
  is_approved TINYINT(1) NOT NULL DEFAULT 0,
  notes TEXT NULL,
  PRIMARY KEY (uuid),
  KEY idx_vacation_employee (employee_uuid),
  CONSTRAINT fk_vacation_employee
    FOREIGN KEY (employee_uuid) REFERENCES employees (uuid),
  CHECK (deleted IN (0, 1)),
  CHECK (is_approved IN (0, 1))
);

CREATE TABLE payroll_results (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  employee_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  year SMALLINT NOT NULL,
  month TINYINT NOT NULL,
  base_days DOUBLE NOT NULL DEFAULT 0.0,
  field_days DOUBLE NOT NULL DEFAULT 0.0,
  sick_days DOUBLE NOT NULL DEFAULT 0.0,
  vacation_days DOUBLE NOT NULL DEFAULT 0.0,
  total_salary DOUBLE NOT NULL DEFAULT 0.0,
  base_rate_used DOUBLE NULL,
  field_rate_used DOUBLE NULL,
  calculated_at VARCHAR(32) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'calculated',
  skipped_work_days INT NOT NULL DEFAULT 0,
  not_deleted TINYINT AS (IF(deleted = 0, 1, NULL)) VIRTUAL,
  PRIMARY KEY (uuid),
  UNIQUE KEY idx_payroll_unique (employee_uuid, year, month, not_deleted),
  KEY idx_payroll_period (year, month),
  CONSTRAINT fk_payroll_results_employee
    FOREIGN KEY (employee_uuid) REFERENCES employees (uuid),
  CHECK (deleted IN (0, 1)),
  CHECK (month BETWEEN 1 AND 12),
  CHECK (status IN ('calculated', 'verified', 'discrepancy'))
);

-- Пользователи сервера. Логин без учёта регистра (сравнение _ai_ci).
CREATE TABLE users (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  login VARCHAR(64) NOT NULL,
  password_hash VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  role VARCHAR(16) NOT NULL,
  full_name VARCHAR(255) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  -- После сброса пароля админом пользователь обязан сменить его сам.
  must_change_password TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
    ON UPDATE CURRENT_TIMESTAMP(6),
  password_changed_at DATETIME(6) NULL,
  PRIMARY KEY (uuid),
  UNIQUE KEY uq_users_login (login),
  CHECK (role IN ('admin', 'accountant', 'operator')),
  CHECK (is_active IN (0, 1)),
  CHECK (must_change_password IN (0, 1))
);

-- Refresh-токены хранятся только хэшем (sha256, hex). family — цепочка
-- токенов одного входа: повторное использование старого токена отзывает
-- всю цепочку.
CREATE TABLE refresh_tokens (
  token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  user_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  family CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  device_id VARCHAR(64) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  expires_at DATETIME(6) NOT NULL,
  revoked_at DATETIME(6) NULL,
  PRIMARY KEY (token_hash),
  KEY idx_refresh_tokens_user (user_uuid),
  KEY idx_refresh_tokens_family (family),
  CONSTRAINT fk_refresh_tokens_user
    FOREIGN KEY (user_uuid) REFERENCES users (uuid)
);

-- Журнал действий: только добавление. Без внешних ключей, чтобы запись
-- аудита не зависела от судьбы пользователя.
CREATE TABLE audit_log (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  user_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  device_id VARCHAR(64) NULL,
  request_id VARCHAR(64) NULL,
  action VARCHAR(32) NOT NULL,
  entity VARCHAR(64) NULL,
  entity_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  old_value JSON NULL,
  new_value JSON NULL,
  PRIMARY KEY (id),
  KEY idx_audit_entity (entity, entity_uuid),
  KEY idx_audit_created (created_at),
  KEY idx_audit_user (user_uuid, created_at)
);

-- Закрытые месяцы. Открытие месяца — удаление строки (с записью в аудит).
CREATE TABLE period_locks (
  year SMALLINT NOT NULL,
  month TINYINT NOT NULL,
  locked_by CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  locked_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  note VARCHAR(500) NULL,
  PRIMARY KEY (year, month),
  CONSTRAINT fk_period_locks_user
    FOREIGN KEY (locked_by) REFERENCES users (uuid),
  CHECK (month BETWEEN 1 AND 12)
);

-- Курсор pull-синхронизации: запись в той же транзакции, что и изменение.
-- Порядок seq должен совпадать с порядком фиксации транзакций — запись
-- изменений сериализуется (шаг 2.4), иначе клиент может пропустить
-- изменение с меньшим seq, зафиксированное позже.
CREATE TABLE change_log (
  seq BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  table_name VARCHAR(64) NOT NULL,
  entity_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  operation VARCHAR(16) NOT NULL,
  changed_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (seq),
  KEY idx_change_log_entity (table_name, entity_uuid),
  CHECK (operation IN ('upsert', 'delete'))
);
