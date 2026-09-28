-- Снимки расчётов и остатков перед открытием закрытого месяца (6.2).
--
-- Открытие месяца пересчитывает его расчёт и расчёты следующих открытых
-- месяцев — прежние суммы перестают существовать в данных. Снимок хранит их:
-- по каждому месяцу, начиная с открытого, по каждому сотруднику — остаток
-- на начало, начислено, выплачено (остаток на конец = начало + начислено −
-- выплачено). Только на сервере, клиентам не синхронизируется; пишется в
-- той же транзакции, что и открытие, и не меняется.
CREATE TABLE period_snapshots (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  year SMALLINT NOT NULL,
  month TINYINT NOT NULL,
  reason VARCHAR(32) NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  created_by CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  -- Закрытие, которое сняли: кто, когда, примечание.
  lock_info JSON NULL,
  data JSON NOT NULL,
  PRIMARY KEY (id),
  KEY idx_period_snapshots_month (year, month),
  CONSTRAINT fk_period_snapshots_user
    FOREIGN KEY (created_by) REFERENCES users (uuid),
  CHECK (month BETWEEN 1 AND 12)
);
